{{/*
OpenTelemetry Collector Configuration Helper Templates
*/}}

{{/*
Generate OpenTelemetry Collector image
*/}}
{{- define "opentelemetry-kube-stack.collectorImage" -}}
{{- if .Values.image }}
{{- .Values.image }}
{{- else }}
{{- .Values.imageRepository | default "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s" }}:{{ .Values.imageTag | default "latest" }}
{{- end }}
{{- end }}

{{/*
Generate environment variables for OpenTelemetry Collector
*/}}
{{- define "opentelemetry-kube-stack.collectorEnv" -}}
- name: TSUGA_OTLP_ENDPOINT
  value: {{ .Values.tsuga.otlpEndpoint }}
- name: MY_POD_IP
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.podIP
{{- if or .Values.secret.create .Values.secret.existing.enabled }}
- name: TSUGA_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_API_KEY" "Values" .Values) }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Agent extensions
*/}}
{{- define "opentelemetry-kube-stack.agentExtensions" -}}
health_check:
  endpoint: ${env:MY_POD_IP}:13133
{{- if and .Values.agent.config .Values.agent.config.extensions }}
{{- toYaml .Values.agent.config.extensions | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Agent service extensions
*/}}
{{- define "opentelemetry-kube-stack.serviceExtensions" -}}
- health_check
{{- end }}

{{/*
Generate OpenTelemetry Agent telemetry configuration
*/}}
{{- define "opentelemetry-kube-stack.telemetryConfig" -}}
{{- if and .Values.agent.config .Values.agent.config.telemetry }}
{{- toYaml .Values.agent.config.telemetry | nindent 0 }}
{{- else }}
metrics:
  readers:
  - pull:
      exporter:
        prometheus:
          host: ${env:MY_POD_IP}
          port: 8888
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Agent receivers configuration
*/}}
{{- define "opentelemetry-kube-stack.agentReceivers" -}}
{{- if eq .Values.agent.enabled true }}
{{- if and .Values.agent.config .Values.agent.config.receivers }}
{{- toYaml .Values.agent.config.receivers | nindent 0 }}
{{- else }}
# Agent receivers
filelog:
  exclude: []
  include:
  - /var/log/pods/*/*/*.log
{{- if eq .Values.agent.collectOtelLogs false}}
  exclude:
  - /var/log/pods/*/otel-collector/*.log
{{- end }}
  include_file_name: false
  include_file_path: true
  operators:
  - id: container-parser
    max_log_size: 102400
    type: container
  retry_on_failure:
    enabled: true
  start_at: end
jaeger:
  protocols:
    grpc:
      endpoint: ${env:MY_POD_IP}:14250
    thrift_compact:
      endpoint: ${env:MY_POD_IP}:6831
    thrift_http:
      endpoint: ${env:MY_POD_IP}:14268
kubeletstats:
  insecure_skip_verify: true
  auth_type: serviceAccount
  collection_interval: 20s
  endpoint: ${env:K8S_NODE_NAME}:10250
otlp:
  protocols:
    grpc:
      endpoint: ${env:MY_POD_IP}:4317
    http:
      endpoint: ${env:MY_POD_IP}:4318
prometheus:
  config:
    scrape_configs:
    - job_name: opentelemetry-collector
      scrape_interval: 10s
      static_configs:
      - targets:
        - ${env:MY_POD_IP}:8888
zipkin:
  endpoint: ${env:MY_POD_IP}:9411
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Cluster receivers configuration
*/}}
{{- define "opentelemetry-kube-stack.clusterReceivers" -}}
{{- if eq .Values.cluster.enabled true }}
{{- if and .Values.cluster.config .Values.cluster.config.receivers }}
{{- toYaml .Values.cluster.config.receivers | nindent 0 }}
{{- else }}
k8s_cluster:
  collection_interval: 10s
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate Tsuga exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.tsugaExporters" -}}
otlphttp/tsuga:
  endpoint: ${TSUGA_OTLP_ENDPOINT}
  headers:
    Authorization: Bearer ${TSUGA_API_KEY}
{{- end }}

{{/*
Generate OpenTelemetry Agent exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.agentExporters" -}}
{{include "opentelemetry-kube-stack.tsugaExporters" .}}
{{- if and .Values.agent.config .Values.agent.config.exporters }}
{{- toYaml .Values.agent.config.exporters | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Cluster exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.clusterExporters" -}}
{{include "opentelemetry-kube-stack.tsugaExporters" .}}
{{- if and .Values.cluster.config .Values.cluster.config.exporters }}
{{- toYaml .Values.cluster.config.exporters | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Agent processors configuration
*/}}
{{- define "opentelemetry-kube-stack.agentProcessors" -}}
{{- if eq .Values.agent.enabled true }}
{{- if and .Values.agent.config .Values.agent.config.processors }}
{{- toYaml .Values.agent.config.processors | nindent 0 }}
{{- else }}
# Agent processors
batch: {}
k8sattributes:
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
    - k8s.node.name
  filter:
    node_from_env_var: K8S_NODE_NAME
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
memory_limiter:
  check_interval: 5s
  limit_percentage: 80
  spike_limit_percentage: 25
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Cluster processors configuration
*/}}
{{- define "opentelemetry-kube-stack.clusterProcessors" -}}
{{- if eq .Values.cluster.enabled true }}
{{- if and .Values.cluster.config .Values.cluster.config.processors }}
{{- toYaml .Values.cluster.config.processors | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Agent service pipelines
*/}}
{{- define "opentelemetry-kube-stack.agentServicePipelines" -}}
{{- if eq .Values.agent.enabled true }}
# Agent pipelines
logs:
  exporters:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.exporters }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.exporters | nindent 2 }}
  {{- else }}
  - otlphttp/tsuga
  {{- end }}
  processors:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.processors }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.processors | nindent 2 }}
  {{- else }}
  - k8sattributes
  - memory_limiter
  - batch
  {{- end }}
  receivers:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.receivers }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.receivers | nindent 2 }}
  {{- else }}
  - otlp
  - filelog
  {{- end }}
metrics:
  exporters:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.exporters }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.exporters | nindent 2 }}
  {{- else }}
  - otlphttp/tsuga
  {{- end }}
  processors:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.processors }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.processors | nindent 2 }}
  {{- else }}
  - k8sattributes
  - memory_limiter
  - batch
  {{- end }}
  receivers:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.receivers }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.receivers | nindent 2 }}
  {{- else }}
  - otlp
  - prometheus
  - kubeletstats
  - spanmetrics
  {{- end }}
traces:
  exporters:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.exporters }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.exporters | nindent 2 }}
  {{- else }}
  - otlphttp/tsuga
  - spanmetrics
  {{- end }}
  processors:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.processors }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.processors | nindent 2 }}
  {{- else }}
  - k8sattributes
  - memory_limiter
  - batch
  {{- end }}
  receivers:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.receivers }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.receivers | nindent 2 }}
  {{- else }}
  - otlp
  - jaeger
  - zipkin
  {{- end }}
{{- end }}
{{- end }}



{{/*
Generate OpenTelemetry Cluster service pipelines
*/}}
{{- define "opentelemetry-kube-stack.clusterServicePipelines" -}}
{{- if eq .Values.cluster.enabled true }}
# Gateway pipelines
metrics:
  receivers:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.metrics .Values.cluster.config.service.pipelines.metrics.receivers }}
  {{- toYaml .Values.cluster.config.service.pipelines.metrics.receivers | nindent 2 }}
  {{- else }}
  - k8s_cluster
  {{- end }}
  exporters:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.metrics .Values.cluster.config.service.pipelines.metrics.exporters }}
  {{- toYaml .Values.cluster.config.service.pipelines.metrics.exporters | nindent 2 }}
  {{- else }}
  - otlphttp/tsuga
  {{- end }}
logs/entity_events:
  receivers:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.receivers }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.receivers | nindent 2 }}
  {{- else }}
  - k8s_cluster
  {{- end }}
  exporters:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.exporters }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.exporters | nindent 2 }}
  {{- else }}
  - otlphttp/tsuga
  {{- end }}
{{- end }}
{{- end }}


