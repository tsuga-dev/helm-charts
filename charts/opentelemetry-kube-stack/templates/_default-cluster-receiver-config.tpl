{{- define "tsuga-otel.cluster-receiver.config.default" -}}
receivers:
  k8s_cluster:
    collection_interval: 10s
    allocatable_types_to_report: [cpu, memory, storage]
    node_conditions_to_report: [Ready, MemoryPressure, DiskPressure, PIDPressure]
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
  prometheus/self:
    config:
      scrape_configs:
        - job_name: otel-collector
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:8888']
processors:
  batch:
    # Trigger a send when the batch reaches 1000 items.
    send_batch_size: 5000
    # Enforce a hard limit of 5000 items per batch. This prevents the
    # timeout from creating a massive batch that would be rejected.
    send_batch_max_size: 5000
  k8s_attributes:
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
  cumulativetodelta: {}
  resource/collector:
    attributes:
      - key: service.instance.id
        value: ${POD_UID}
        action: upsert
      {{- if .Values.clusterName }}
      - key: k8s.cluster.name
        value: {{ .Values.clusterName }}
        action: upsert
      {{- end }}
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
{{- if .Values.cluster.collectk8sobjects }}
        - k8s_objects
{{- end }}
      processors:
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
        {{- if .Values.clusterName }}
        - resource
        {{- end }}
        - k8s_attributes
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
        - otlp_http/tsuga
        {{- end }}
    metrics/collector:
      receivers:
        - prometheus/self
      processors:
        - cumulativetodelta
        - resource/collector
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForClusterReceiver") false }}
        - otlp_http/tsuga
        {{- end }}
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
