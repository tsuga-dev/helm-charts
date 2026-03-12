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
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
service:
  pipelines:
    metrics:
      receivers:
        - prometheus
      processors:
        - memory_limiter
        - cumulativetodelta
        - k8sattributes
        - batch
        {{- if .Values.clusterName }}
        - resource
        {{- end }}
      exporters:
        - otlphttp/tsuga
{{- end}}
