{{- define "tsuga-otel.statefulset.config.default" -}}
receivers:
  prometheus:
    config:
      scrape_configs:
        # This placeholder config is required but the Target Allocator
        # will override it with dynamically discovered targets
        - job_name: 'otel-collector'
          scrape_interval: 30s
          static_configs:
            - targets: ['localhost:8888']
    target_allocator:
      endpoint: http://{{ include "opentelemetry-kube-stack.fullname" . }}-ta:80
      interval: 30s
      collector_id: ${POD_NAME}

processors:
  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25
  batch:
    send_batch_size: 5000
    send_batch_max_size: 5000
  cumulativetodelta: {}
  k8s_attributes:
    extract:
      {{- include "opentelemetry-kube-stack.k8sAttributesExtract" (dict "extraLabelMapping" .Values.statefulset.extraLabelMapping "extraAnnotationsMapping" .Values.statefulset.extraAnnotationsMapping) | nindent 6 }}
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
  {{- if .Values.clusterName }}
  resource:
    attributes:
      - key: k8s.cluster.name
        value: {{ .Values.clusterName }}
        action: upsert
  {{- end }}
exporters:
{{- if ne (index .Values "tsuga" "enabledForStatefulset") false }}
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
{{- else }}
  {}
{{- end }}
service:
  pipelines:
    metrics:
      receivers:
        - prometheus
      processors:
        - memory_limiter
        - cumulativetodelta
        - k8s_attributes
        {{- if .Values.clusterName }}
        - resource
        {{- end }}
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForStatefulset") false }}
        - otlp_http/tsuga
        {{- end }}
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
