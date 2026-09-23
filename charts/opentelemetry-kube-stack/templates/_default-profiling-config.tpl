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
    # The receiver already sets the resource from each process's own OTel
    # process context, or failing that its OTEL_SERVICE_NAME and
    # OTEL_RESOURCE_ATTRIBUTES, without reporting either variable.
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
{{- if .Values.resourceDetection.enabled }}
  {{- include "opentelemetry-kube-stack.resourceDetection" . | nindent 2 }}
{{- end }}
{{- if $envVar }}
  # Runs before k8s_attributes on purpose. k8s_attributes only fills an
  # attribute that is not already set, so promoting the process's own variable
  # first makes it win, and the Kubernetes precedence chain k8s_attributes
  # implements covers whatever is left. The delete_key is what keeps the raw
  # env-var attribute from becoming a dimension of its own.
  transform/service_name:
    error_mode: ignore
    profile_statements:
      - context: resource
        statements:
          - set(resource.attributes["service.name"], resource.attributes["process.environment_variable.{{ $envVar }}"]) where resource.attributes["process.environment_variable.{{ $envVar }}"] != nil and resource.attributes["process.environment_variable.{{ $envVar }}"] != ""
          - delete_key(resource.attributes, "process.environment_variable.{{ $envVar }}")
{{- end }}
  k8s_attributes:
    extract:
      metadata:
        {{- toYaml (.Values.profiling.k8sAttributesMetadata | default (list "k8s.namespace.name" "k8s.deployment.name" "k8s.statefulset.name" "k8s.daemonset.name" "k8s.cronjob.name" "k8s.job.name" "k8s.node.name" "k8s.container.name" "container.image.name" "container.image.tags" "service.name" "service.version")) | nindent 8 }}
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
  # Host processes, which no pod matches. containerd gives every shim its own
  # OTEL_SERVICE_NAME, containerd-shim-<container id>, so each pod would add a
  # service. The rest get the OTel SDK fallback, unknown_service:<executable>,
  # rather than all landing in Tsuga's "unknown".
  transform/host_processes:
    error_mode: ignore
    profile_statements:
      - context: resource
        statements:
          - set(resource.attributes["service.name"], "containerd-shim") where IsMatch(resource.attributes["service.name"], "^containerd-shim-[0-9a-f]{64}$")
          - set(resource.attributes["service.name"], Concat(["unknown_service", resource.attributes["process.executable.name"]], ":")) where resource.attributes["service.name"] == nil and resource.attributes["process.executable.name"] != nil
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
{{- if .Values.resourceDetection.enabled }}
        - resource_detection
{{- end }}
{{- if $envVar }}
        # After resource_detection, so a service.name the collector's own
        # OTEL_RESOURCE_ATTRIBUTES happened to carry does not outrank the one
        # the profiled process reports for itself.
        - transform/service_name
{{- end }}
        - k8s_attributes
        - transform/host_processes
        - resource
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForProfiling") false }}
        - otlp_http/tsuga
        {{- end }}
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
