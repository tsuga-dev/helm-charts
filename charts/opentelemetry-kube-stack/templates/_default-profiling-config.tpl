{{- define "tsuga-otel.profiling.config.default" -}}
{{- $healthCheck := .Values.profiling.healthCheckEndpoint | default "" }}
{{- $envVar := .Values.profiling.serviceNameEnvVar | default "" }}
{{- if $healthCheck }}
extensions:
  health_check:
    endpoint: {{ $healthCheck }}
{{- end }}
receivers:
  profiling:
    samples_per_second: {{ .Values.profiling.samplesPerSecond | default 20 }}
    {{- if $envVar }}
    # Surfaced by the receiver as the resource attribute
    # process.environment_variable.<NAME>, which transform/service_name below
    # promotes and then deletes. One variable only: every attribute that
    # survives to the exporter is a metric dimension in Tsuga.
    include_env_vars: {{ $envVar | quote }}
    {{- end }}

processors:
  memory_limiter:
    check_interval: 5s
    limit_percentage: 80
    spike_limit_percentage: 25
{{- if $envVar }}
  # Runs before k8s_attributes on purpose. k8s_attributes only fills an
  # attribute that is not already set, so promoting the process's own
  # OTEL_SERVICE_NAME first makes it win, and the Kubernetes precedence chain
  # k8s_attributes implements covers whatever is left. The delete_key is what
  # keeps the raw env-var attribute from becoming a dimension of its own.
  transform/service_name:
    error_mode: ignore
    profile_statements:
      - context: resource
        statements:
          - set(attributes["service.name"], attributes["process.environment_variable.{{ $envVar }}"]) where attributes["process.environment_variable.{{ $envVar }}"] != nil and attributes["process.environment_variable.{{ $envVar }}"] != ""
          - delete_key(attributes, "process.environment_variable.{{ $envVar }}")
{{- end }}
  k8s_attributes:
    extract:
      metadata:
        {{- toYaml (.Values.profiling.k8sAttributesMetadata | default (list "k8s.namespace.name" "k8s.deployment.name" "k8s.statefulset.name" "k8s.daemonset.name" "k8s.container.name" "service.name" "service.version")) | nindent 8 }}
      annotations:
        - tag_name: service.name
          key: resource.opentelemetry.io/service.name
          from: pod
        - tag_name: service.version
          key: resource.opentelemetry.io/service.version
          from: pod
    # Node-local, so the informer cache holds this node's pods rather than the
    # whole cluster's — the same reason the agent filters.
    filter:
      node_from_env_var: K8S_NODE_NAME
    passthrough: false
    # container.id is the only association key available here: the receiver
    # attaches it (and process.pid, process.executable.*) to each profiled
    # process, and nothing gives it a pod IP or pod UID to match on.
    pod_association:
      - sources:
        - from: resource_attribute
          name: container.id
  resource:
    attributes:
      - key: k8s.cluster.name
        value: {{ include "opentelemetry-kube-stack.clusterName" . }}
        action: upsert
exporters:
{{- if ne (index .Values "tsuga" "enabledForProfiling") false }}
  # Spelled out rather than reusing opentelemetry-kube-stack.tsugaExporters
  # because of one field: encoding is pinned to proto here, ignoring
  # tsuga.encoding. Tsuga's profiles intake takes OTLP/HTTP protobuf, and a
  # chart-wide tsuga.encoding: json would otherwise break profiles alone while
  # every other signal kept working. The exporter appends
  # /v1development/profiles to the endpoint itself — profiles are still an alpha
  # signal upstream, hence v1development and not v1.
  otlp_http/tsuga:
    endpoint: ${TSUGA_OTLP_ENDPOINT}
    headers:
      Authorization: Bearer ${TSUGA_API_KEY}
    encoding: proto
    compression: {{ .Values.tsuga.compression | default "gzip" }}
{{- else }}
  {}
{{- end }}
service:
{{- if $healthCheck }}
  extensions:
    - health_check
{{- end }}
  pipelines:
    # No batch processor: it registers traces, metrics and logs only, so a
    # profiles pipeline referencing it fails at startup. The receiver's own
    # reporter interval (5s) is what groups profiles for export.
    profiles:
      receivers:
        - profiling
      processors:
        - memory_limiter
{{- if $envVar }}
        - transform/service_name
{{- end }}
        - k8s_attributes
        - resource
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForProfiling") false }}
        - otlp_http/tsuga
        {{- end }}
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
