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
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_OTLP_ENDPOINT" "Values" .Values) }}
- name: MY_POD_IP
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.podIP
- name: TSUGA_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_API_KEY" "Values" .Values) }}
{{- end }}

{{/*
Generate OpenTelemetry Agent extensions
*/}}
{{- define "opentelemetry-kube-stack.agentExtensions" -}}
health_check:
  endpoint: ${env:MY_POD_IP}:13133
{{- if and .Values.agent.config .Values.agent.config.extraExtensions }}
{{- toYaml .Values.agent.config.extraExtensions | nindent 0 }}
{{- end }}
{{- if and .Values.agent.config .Values.agent.config.extensions }}
{{- toYaml .Values.agent.config.extensions | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Agent service extensions
*/}}
{{- define "opentelemetry-kube-stack.serviceExtensions" -}}
- health_check
{{- if and .Values.agent.config .Values.agent.config.service.extraExtensions }}
{{- toYaml .Values.agent.config.service.extraExtensions | nindent 0 }}
{{- end }}
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
{{- if .Values.agent.collectLogs }}
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
{{- end }}
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
hostmetrics:
  collection_interval: 10s
  scrapers:
    paging:
      metrics:
        system.paging.utilization:
          enabled: true
    cpu:
      metrics:
        system.cpu.utilization:
          enabled: true
    disk:
    filesystem:
      metrics:
        system.filesystem.utilization:
          enabled: true
    load:
    memory:
    {{- if .Values.agent.collectNetwork }}
    network:
    {{- end }}
    {{- if .Values.agent.collectProcesses }}
    processes:
    process:
      metrics:
        process.uptime:
          enabled: true
    {{- end }}
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
{{- if and .Values.agent.config .Values.agent.config.extraReceivers }}
{{- toYaml .Values.agent.config.extraReceivers | nindent 0 }}
{{- end }}
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
{{- if and .Values.cluster.config .Values.cluster.config.extraReceivers }}
{{- toYaml .Values.cluster.config.extraReceivers | nindent 0 }}
{{- end }}
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
{{- if and .Values.agent.config .Values.agent.config.exporters }}
{{- toYaml .Values.agent.config.exporters | nindent 0 }}
{{- else }}
{{include "opentelemetry-kube-stack.tsugaExporters" .}}
{{- if and .Values.agent.config .Values.agent.config.extraExporters }}
{{- toYaml .Values.agent.config.extraExporters | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate OpenTelemetry Cluster exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.clusterExporters" -}}
{{- if and .Values.cluster.config .Values.cluster.config.exporters }}
{{- toYaml .Values.cluster.config.exporters | nindent 0 }}
{{- else }}
{{include "opentelemetry-kube-stack.tsugaExporters" .}}
{{- if and .Values.cluster.config .Values.cluster.config.extraExporters }}
{{- toYaml .Values.cluster.config.extraExporters | nindent 0 }}
{{- end }}
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
{{- if .Values.labelMapping }}
{{- toYaml .Values.labelMapping | nindent 4 }}
{{- end }}
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
cumulativetodelta: {}
resource:
  attributes:
  - key: k8s.cluster.name
    value: {{ .Values.clusterName }}
    action: upsert
{{- if and .Values.agent.config .Values.agent.config.extraProcessors }}
{{- toYaml .Values.agent.config.extraProcessors | nindent 0 }}
{{- end }}
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
{{- else }}
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
{{- if .Values.labelMapping }}
{{- toYaml .Values.labelMapping | nindent 4 }}
{{- end }}
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
    value: {{ .Values.clusterName }}
    action: upsert
{{- if and .Values.cluster.config .Values.cluster.config.extraProcessors }}
{{- toYaml .Values.cluster.config.extraProcessors | nindent 0 }}
{{- end }}
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
  {{- toYaml .Values.agent.config.service.pipelines.logs.exporters | nindent 4 }}
  {{- else }}
    - otlphttp/tsuga
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.extraExporters }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.extraExporters | nindent 4 }}
  {{- end }}
  {{- end }}
  processors:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.processors }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.processors | nindent 4}}
  {{- else }}
    - k8sattributes
    - memory_limiter
    - batch
    - resource
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.extraProcessors }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.extraProcessors | nindent 4 }}
  {{- end }}
  {{- end }}
  receivers:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.receivers }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.receivers | nindent 4 }}
  {{- else }}
    - otlp
    - filelog
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.logs .Values.agent.config.service.pipelines.logs.extraReceivers }}
  {{- toYaml .Values.agent.config.service.pipelines.logs.extraReceivers | nindent 4 }}
  {{- end }}
  {{- end }}
metrics:
  exporters:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.exporters }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.exporters | nindent 4 }}
  {{- else }}
    - otlphttp/tsuga
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.extraExporters }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.extraExporters | nindent 4 }}
  {{- end }}
  {{- end }}
  processors:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.processors }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.processors | nindent 4 }}
  {{- else }}
    - k8sattributes
    - memory_limiter
    - batch
    - cumulativetodelta
    - resource
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.extraProcessors }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.extraProcessors | nindent 4 }}
  {{- end }}
  {{- end }}
  receivers:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.receivers }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.receivers | nindent 4 }}
  {{- else }}
    - otlp
    - prometheus
    - kubeletstats
    - spanmetrics
    - hostmetrics
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.metrics .Values.agent.config.service.pipelines.metrics.extraReceivers }}
  {{- toYaml .Values.agent.config.service.pipelines.metrics.extraReceivers | nindent 4 }}
  {{- end }}
  {{- end }}
traces:
  exporters:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.exporters }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.exporters | nindent 4 }}
  {{- else }}
    - otlphttp/tsuga
    - spanmetrics
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.extraExporters }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.extraExporters | nindent 4 }}
  {{- end }}
  {{- end }}
  processors:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.processors }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.processors | nindent 4 }}
  {{- else }}
    - k8sattributes
    - memory_limiter
    - batch
    - resource
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.extraProcessors }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.extraProcessors | nindent 4 }}
  {{- end }}
  {{- end }}
  receivers:
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.receivers }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.receivers | nindent 4 }}
  {{- else }}
    - otlp
    - jaeger
    - zipkin
  {{- if and .Values.agent.config .Values.agent.config.service .Values.agent.config.service.pipelines .Values.agent.config.service.pipelines.traces .Values.agent.config.service.pipelines.traces.extraReceivers }}
  {{- toYaml .Values.agent.config.service.pipelines.traces.extraReceivers | nindent 4 }}
  {{- end }}
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
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.metrics .Values.cluster.config.service.pipelines.metrics.extraReceivers }}
  {{- toYaml .Values.cluster.config.service.pipelines.metrics.extraReceivers | nindent 2 }}
  {{- end}}
  {{- end }}
  exporters:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.metrics .Values.cluster.config.service.pipelines.metrics.exporters }}
  {{- toYaml .Values.cluster.config.service.pipelines.metrics.exporters | nindent 2 }}
  {{- else }}
  - otlphttp/tsuga
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.metrics .Values.cluster.config.service.pipelines.metrics.extraExporters }}
  {{- toYaml .Values.cluster.config.service.pipelines.metrics.extraExporters | nindent 2 }}
  {{- end}}
  {{- end }}
  processors:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.metrics .Values.cluster.config.service.pipelines.metrics.processors }}
  {{- toYaml .Values.cluster.config.service.pipelines.metrics.processors | nindent 2 }}
  {{- else }}
  - resource
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.metrics .Values.cluster.config.service.pipelines.metrics.extraProcessors }}
  {{- toYaml .Values.cluster.config.service.pipelines.metrics.extraProcessors | nindent 2 }}
  {{- end }}
  {{- end }}
logs/entity_events:
  receivers:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.receivers }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.receivers | nindent 2 }}
  {{- else }}
  - k8s_cluster
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.extraReceivers }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.extraReceivers | nindent 2 }}
  {{- end}}
  {{- end }}
  exporters:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.exporters }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.exporters | nindent 2 }}
  {{- else }}
  - otlphttp/tsuga
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.extraExporters }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.extraExporters | nindent 2 }}
  {{- end}}
  {{- end }}
  processors:
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.processors }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.processors | nindent 2 }}
  {{- else }}
  - resource
  {{- if and .Values.cluster.config .Values.cluster.config.service .Values.cluster.config.service.pipelines .Values.cluster.config.service.pipelines.logs .Values.cluster.config.service.pipelines.logs.extraProcessors }}
  {{- toYaml .Values.cluster.config.service.pipelines.logs.extraProcessors | nindent 2 }}
  {{- end}}
  {{- end }}
{{- end }}
{{- end }}