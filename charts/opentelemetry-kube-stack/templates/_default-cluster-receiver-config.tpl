{{- define "tsuga-otel.cluster-receiver.config.default" -}}
receivers:
  k8s_cluster:
    collection_interval: 10s
    allocatable_types_to_report: [cpu, memory, storage]
    node_conditions_to_report: [Ready, MemoryPressure, DiskPressure, PIDPressure]
    metrics:
      k8s.pod.status_reason:
        enabled: true
{{- if .Values.cluster.collectk8sobjects }}
  k8s_objects:
    auth_type: serviceAccount
    include_initial_state: true
    objects:
      - group: ""
        name: pods
        mode: watch
{{- end }}
{{- if .Values.cluster.collectk8sevents }}
  # A separate instance, only so events can set include_initial_state: false —
  # the field is receiver-wide, and the pods stream above needs the snapshot.
  #
  # Without that, every collector restart re-emits the API server's whole
  # retained event window (an hour by default) as new records. This chart
  # restarts the cluster receiver on every helm upgrade by design, so shared
  # settings would turn each upgrade into an hour of duplicated warnings. The
  # receiver still lists once to obtain a resourceVersion, it just does not
  # emit that snapshot, so the cost is only warnings raised while the collector
  # was down.
  #
  # Kubernetes events are the only source for OOMKilled, FailedScheduling,
  # Evicted, ErrImagePull, FailedMount and failing probes: no metric receiver
  # reports them.
  #
  # field_selector filters at the API server, so Normal events are never
  # watched, transferred or processed. type is a selectable field on both
  # core/v1 and events.k8s.io/v1, and the receiver applies the selector to the
  # initial list as well as the watch. Normal events are the high-volume,
  # low-value majority and restate what the pods stream already carries.
  #
  # Worth knowing if this is ever edited: the API server rejects an unsupported
  # selector name with "field label not supported", but the receiver logs that
  # in a background goroutine rather than failing startup. A typo here yields one
  # log line and silence, not a crash.
  #
  # Also: replicas is 1 but the rollout is unbounded, so a helm upgrade briefly
  # runs two cluster receivers. Both watch, so warnings raised in that window
  # arrive twice. include_initial_state: false keeps that to the overlap rather
  # than the whole retained window.
  #
  # Not addressed here: repeated warnings are not de-duplicated. A
  # CrashLoopBackOff bumping an event's count emits another record each time.
  # The k8s_events receiver gained a dedup_interval for this, but only in
  # v0.155.0, above this chart's floor, and its storage-based alternative needs
  # a file_storage extension this chart does not ship.
  k8s_objects/events:
    auth_type: serviceAccount
    include_initial_state: false
    objects:
      - group: events.k8s.io
        name: events
        mode: watch
        field_selector: type=Warning
{{- end }}
processors:
  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25
  batch:
    # Trigger a send when the batch reaches 1000 items.
    send_batch_size: 5000
    # Enforce a hard limit of 5000 items per batch. This prevents the
    # timeout from creating a massive batch that would be rejected.
    send_batch_max_size: 5000
{{- if .Values.resourceDetection.enabled }}
  {{- include "opentelemetry-kube-stack.resourceDetection" . | nindent 2 }}
{{- end }}
{{- if .Values.cluster.collectk8sevents }}
  # k8s_objects sets no severity on the records it emits, and Tsuga normalizes a
  # missing or invalid level to INFO — which would file every OOMKill and
  # FailedScheduling as routine. WARN is one of the values Tsuga recognizes.
  #
  # No condition, because this runs in a pipeline fed only by
  # k8s_objects/events, and that receiver is filtered to type=Warning at the API
  # server. Conditions here would also be a liability: indexing into a log body
  # that is not a map errors per record, which under error_mode: ignore means a
  # warning logged for every record.
  transform/k8s_event_severity:
    error_mode: ignore
    log_statements:
      - set(log.severity_text, "WARN")
      - set(log.severity_number, SEVERITY_NUMBER_WARN)
{{- end }}
  k8s_attributes:
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.deployment.name
        - k8s.statefulset.name
        - k8s.daemonset.name
        - k8s.cronjob.name
        - k8s.job.name
        - k8s.node.name
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.pod.start_time
      labels:
        - tag_name: service.name
          key: resource.opentelemetry.io/service.name
          from: pod
        - tag_name: service.version
          key: resource.opentelemetry.io/service.version
          from: pod
        - tag_name: env
          key: resource.opentelemetry.io/env
          from: pod
        - tag_name: team
          key: resource.opentelemetry.io/team
          from: pod
{{- if .Values.cluster.extraLabelMapping }}
{{- toYaml .Values.cluster.extraLabelMapping | nindent 8 }}
{{- end}}
      annotations:
        - tag_name: service.name
          key: resource.opentelemetry.io/service.name
          from: pod
        - tag_name: service.version
          key: resource.opentelemetry.io/service.version
          from: pod
        - tag_name: env
          key: resource.opentelemetry.io/env
          from: pod
        - tag_name: team
          key: resource.opentelemetry.io/team
          from: pod
{{- if .Values.cluster.extraAnnotationsMapping }}
{{- toYaml .Values.cluster.extraAnnotationsMapping | nindent 8 }}
{{- end}}
    passthrough: false
    pod_association:
      - sources:
        - from: resource_attribute
          name: k8s.pod.ip
      - sources:
        - from: resource_attribute
          name: k8s.pod.uid
      - sources:
        - from: connection
  resource:
    attributes:
      - key: k8s.cluster.name
        value: {{ include "opentelemetry-kube-stack.clusterName" . }}
        action: upsert
exporters:
{{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
{{- else }}
  {}
{{- end }}
service:
  pipelines:
    logs:
      receivers:
        - k8s_cluster
{{- if .Values.cluster.collectk8sobjects }}
        - k8s_objects
{{- end }}

      processors:
        - memory_limiter
{{- if .Values.resourceDetection.enabled }}
        - resourcedetection
{{- end }}
        - k8s_attributes
        - resource
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
        - otlp_http/tsuga
        {{- end }}
{{- if .Values.cluster.collectk8sevents }}
    # Its own pipeline so the severity transform only ever sees event records.
    #
    # k8s_attributes is deliberately absent: a k8s_objects watch record carries
    # only k8s.namespace.name as a resource attribute, and none of the
    # pod_association sources this chart configures (k8s.pod.ip, k8s.pod.uid,
    # connection) can match one, so the processor would run and change nothing.
    logs/events:
      receivers:
        - k8s_objects/events
      processors:
        - memory_limiter
{{- if .Values.resourceDetection.enabled }}
        - resourcedetection
{{- end }}
        - transform/k8s_event_severity
        - resource
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
        - otlp_http/tsuga
        {{- end }}
{{- end }}
    metrics:
      receivers:
        - k8s_cluster
      processors:
        - memory_limiter
{{- if .Values.resourceDetection.enabled }}
        - resourcedetection
{{- end }}
        - k8s_attributes
        - resource
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
        - otlp_http/tsuga
        {{- end }}
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
