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
  cumulative_to_delta: {}
{{- if .Values.resourceDetection.enabled }}
  {{- include "opentelemetry-kube-stack.resourceDetection" . | nindent 2 }}
{{- end }}
  k8s_attributes:
    extract:
      metadata:
        {{- include "opentelemetry-kube-stack.k8sAttributesMetadata" . | nindent 8 }}
      # service.name and service.version are deliberately not mapped here from a
      # pod label: the spec only defines resource.opentelemetry.io/service.name
      # and .../service.version as pod *annotations* (below), and once
      # k8sAttributesMetadata's service.name/service.version entries activate the
      # processor's own app.kubernetes.io/instance and .../name label precedence,
      # a same-named label rule here would run before those and lose to them —
      # silently inverting precedence. Annotations run last and are unaffected.
      labels:
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
      # k8s.pod.uid is what the prometheus receiver sets on scraped targets, so it
      # is the only rule that resolves for the default pipeline. The two below are
      # kept for receivers added through extraReceivers: an inbound OTLP receiver
      # gives `connection` a client address, and an upstream collector running
      # k8s_attributes in passthrough mode sets k8s.pod.ip. A rule that cannot
      # resolve is skipped, so they cost nothing here.
      - sources:
        - from: resource_attribute
          name: k8s.pod.uid
      - sources:
        - from: resource_attribute
          name: k8s.pod.ip
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
        - cumulative_to_delta
{{- if .Values.resourceDetection.enabled }}
        - resource_detection
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
