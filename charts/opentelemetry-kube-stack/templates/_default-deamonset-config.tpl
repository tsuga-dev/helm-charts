{{- define "tsuga-otel.deamonset.config.default" -}}
extensions:
  health_check:
    endpoint: ${env:MY_POD_IP}:13133
receivers:
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
processors:
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
{{- if .Values.agent.extraLabelMapping }}
{{- toYaml .Values.agent.extraLabelMapping | nindent 8 }}
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
{{- if .Values.agent.extraAnnotationsMapping }}
{{- toYaml .Values.agent.extraAnnotationsMapping | nindent 8 }}
{{- end}}
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
exporters: 
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
connectors:
  spanmetrics: {}
service:
  extensions:
    - health_check
  pipelines:
    logs:
      receivers:
        - otlp
{{- if .Values.agent.collectLogs }}
        - filelog
{{- end }}
      processors: 
        - k8sattributes
        - memory_limiter
        - batch
        - resource
      exporters: 
        - otlphttp/tsuga
    metrics:
      receivers:
        - otlp
        - prometheus
        - kubeletstats
        - spanmetrics
        - hostmetrics
      processors: 
        - k8sattributes
        - memory_limiter
        - batch
        - cumulativetodelta
        - resource
      exporters: 
        - otlphttp/tsuga
    traces:
      exporters:
        - otlphttp/tsuga
        - spanmetrics
      processors:
        - k8sattributes
        - memory_limiter
        - batch
        - resource
      receivers:
        - otlp
        - jaeger
        - zipkin
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus:
                host: ${env:MY_POD_IP}
                port: 8888
{{- end}}