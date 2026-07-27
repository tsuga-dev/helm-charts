{{- define "tsuga-otel.cluster-receiver.config.default" -}}
receivers:
  k8s_cluster:
    collection_interval: 10s
    allocatable_types_to_report: [cpu, memory, storage]
    node_conditions_to_report: [Ready, MemoryPressure, DiskPressure, PIDPressure]
    metrics:
      k8s.pod.status_reason:
        enabled: true
{{- if or .Values.cluster.collectk8sobjects .Values.cluster.collectk8sevents }}
  k8s_objects:
    auth_type: serviceAccount
    # Receiver-wide (the field does not exist per-object): on start, snapshot
    # current objects before watching. For events that means the API server's
    # retained window (1h by default) is replayed after a collector restart.
    include_initial_state: true
    objects:
    {{- if .Values.cluster.collectk8sobjects }}
      - group: ""
        name: pods
        mode: watch
    {{- end }}
    {{- if .Values.cluster.collectk8sevents }}
      # Warning only. Normal events (Scheduled, Pulling, Pulled, Created,
      # Started) are the bulk of the volume and restate what the pod objects
      # above already show; the diagnostic value - FailedScheduling, BackOff,
      # Evicted, ErrImagePull, FailedMount, Unhealthy - is all type=Warning.
      - group: events.k8s.io
        name: events
        mode: watch
        field_selector: type=Warning
    {{- end }}
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
  k8s_attributes:
    extract:
      {{- include "opentelemetry-kube-stack.k8sAttributesExtract" (dict "extraLabelMapping" .Values.cluster.extraLabelMapping "extraAnnotationsMapping" .Values.cluster.extraAnnotationsMapping) | nindent 6 }}
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
  cumulativetodelta: {}
  {{- if .Values.clusterName }}
  resource:
    attributes:
      - key: k8s.cluster.name
        value: {{ .Values.clusterName }}
        action: upsert
  {{- end }}
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
{{- if or .Values.cluster.collectk8sobjects .Values.cluster.collectk8sevents }}
        - k8s_objects
{{- end }}
      processors:
        - memory_limiter
        {{- if .Values.resourceDetection.enabled }}
        - resource_detection
        {{- end }}
        {{- if .Values.clusterName }}
        - resource
        {{- end }}
        - k8s_attributes
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
        - otlp_http/tsuga
        {{- end }}
    metrics:
      receivers:
        - k8s_cluster
      processors:
        - memory_limiter
        {{- if .Values.resourceDetection.enabled }}
        - resource_detection
        {{- end }}
        {{- if .Values.clusterName }}
        - resource
        {{- end }}
        - k8s_attributes
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
        - otlp_http/tsuga
        {{- end }}
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
