{{- define "tsuga-otel.cluster-receiver.config.default" -}}
{{- $healthCheck := .Values.cluster.healthCheckEndpoint | default "" }}
{{- if $healthCheck }}
extensions:
  health_check:
    endpoint: {{ $healthCheck }}
{{- end }}
receivers:
  k8s_cluster:
    collection_interval: {{ .Values.cluster.collectionInterval | default "10s" }}
    allocatable_types_to_report: {{ toYaml (.Values.cluster.allocatableTypesToReport | default (list "cpu" "memory" "storage")) | nindent 6 }}
    node_conditions_to_report: {{ toYaml (.Values.cluster.nodeConditionsToReport | default (list "Ready" "MemoryPressure" "DiskPressure" "PIDPressure")) | nindent 6 }}
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
  # A separate receiver instance, only so events can set
  # include_initial_state: false — the field is receiver-wide and the pods stream
  # above needs its snapshot. Sharing one would re-emit the API server's entire
  # retained event window (an hour by default) on every collector restart, and a
  # helm upgrade restarts this collector by design.
  #
  # field_selector filters at the API server, so Normal events are never watched
  # or transferred. type is selectable on both core/v1 and events.k8s.io/v1, and
  # applies to the initial list as well as the watch. Careful when editing: the
  # API server rejects an unsupported selector name in a background goroutine, so
  # a typo gives one log line and silence, not a startup failure.
  #
  # Repeated warnings are not de-duplicated; k8s_events gained dedup_interval for
  # that in v0.155.0, above this chart's floor.
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
  {{- include "opentelemetry-kube-stack.batch" . | nindent 2 }}
{{- if .Values.resourceDetection.enabled }}
  {{- include "opentelemetry-kube-stack.resourceDetection" . | nindent 2 }}
{{- end }}
{{- if .Values.cluster.collectk8sevents }}
  # k8s_objects sets no severity, and Tsuga normalizes a missing level to INFO,
  # which would file every OOMKill as routine. No condition is needed because
  # this pipeline only ever carries type=Warning records — and a condition would
  # be a liability, since indexing a log body that is not a map errors once per
  # record under error_mode: ignore.
  transform/k8s_event_severity:
    error_mode: ignore
    log_statements:
      - set(log.severity_text, "WARN")
      - set(log.severity_number, SEVERITY_NUMBER_WARN)
{{- end }}
  k8s_attributes:
    extract:
      metadata:
        {{- include "opentelemetry-kube-stack.k8sAttributesMetadata" . | nindent 8 }}
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
{{- if $healthCheck }}
  extensions:
    - health_check
{{- end }}
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
        - resource_detection
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
    # k8s_attributes is absent deliberately: a k8s_objects watch record carries
    # only k8s.namespace.name, which none of this chart's pod_association sources
    # can match, so the processor would run and change nothing.
    logs/events:
      receivers:
        - k8s_objects/events
      processors:
        - memory_limiter
{{- if .Values.resourceDetection.enabled }}
        - resource_detection
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
        - resource_detection
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
