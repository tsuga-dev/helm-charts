{{- define "tsuga-otel.statefulset.config.default" -}}
receivers:
  prometheus:
    config:
      scrape_configs: []
processors:
  batch:
    send_batch_size: 5000
    send_batch_max_size: 5000
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
        - k8sattributes
        - batch
        {{- if .Values.clusterName }}
        - resource
        {{- end }}
      exporters:
        - otlphttp/tsuga
{{- end}}
