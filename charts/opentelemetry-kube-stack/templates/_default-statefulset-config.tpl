{{- define "tsuga-otel.statefulset.config.default" -}}
{{- $healthCheck := .Values.statefulset.healthCheckEndpoint | default "" }}
{{- if $healthCheck }}
extensions:
  health_check:
    endpoint: {{ $healthCheck }}
{{- end }}
receivers:
  prometheus:
    config:
      scrape_configs:
        # This placeholder config is required but the Target Allocator
        # will override it with dynamically discovered targets
        - job_name: 'otel-collector'
          scrape_interval: {{ .Values.statefulset.scrapeInterval | default "30s" }}
          static_configs:
            - targets: ['localhost:8888']
    target_allocator:
      endpoint: http://{{ include "opentelemetry-kube-stack.fullname" . }}-ta:80
      interval: {{ .Values.statefulset.scrapeInterval | default "30s" }}
      collector_id: ${POD_NAME}

processors:
  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25
  {{- include "opentelemetry-kube-stack.batch" . | nindent 2 }}
  # Runs before enrichment in the pipeline: delta state is keyed on the full
  # resource, so a series that starts unenriched and later gains pod metadata
  # would look like a new series and lose a datapoint to initial_value: auto.
  cumulativetodelta: {}
{{- if .Values.resourceDetection.enabled }}
  {{- include "opentelemetry-kube-stack.resourceDetection" . | nindent 2 }}
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
{{- if .Values.statefulset.extraLabelMapping }}
{{- toYaml .Values.statefulset.extraLabelMapping | nindent 8 }}
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
{{- if .Values.statefulset.extraAnnotationsMapping }}
{{- toYaml .Values.statefulset.extraAnnotationsMapping | nindent 8 }}
{{- end}}
    passthrough: false
    pod_association:
      - sources:
        - from: resource_attribute
          name: net.host.name
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
{{- if ne (index .Values "tsuga" "enabledForStatefulset") false }}
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
    metrics:
      receivers:
        - prometheus
      processors:
        - memory_limiter
        - cumulativetodelta
{{- if .Values.resourceDetection.enabled }}
        - resourcedetection
{{- end }}
        - k8s_attributes
        - resource
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForStatefulset") false }}
        - otlp_http/tsuga
        {{- end }}
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
