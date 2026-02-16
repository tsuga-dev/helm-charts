{{- define "tsuga-otel.cluster-receiver.config.default" -}}
receivers:
  k8s_cluster:
    collection_interval: 10s
    allocatable_types_to_report: [cpu, memory]
processors:
  batch:
    # Trigger a send when the batch reaches 1000 items.
    send_batch_size: 5000
    # Enforce a hard limit of 5000 items per batch. This prevents the
    # timeout from creating a massive batch that would be rejected.
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
        value: {{ .Values.clusterName }}
        action: upsert
exporters:
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
service:
  pipelines:
    logs:
      receivers:
        - k8s_cluster
      processors:
        - resource
        - batch
      exporters:
        - otlphttp/tsuga
    metrics:
      receivers:
        - k8s_cluster
      processors:
        - resource
        - batch
      exporters:
        - otlphttp/tsuga
{{- end}}
