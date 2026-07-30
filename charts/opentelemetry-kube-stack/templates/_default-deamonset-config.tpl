{{- define "tsuga-otel.deamonset.config.default" -}}
{{- $healthCheck := .Values.agent.healthCheckEndpoint | default "" }}
{{- if $healthCheck }}
extensions:
  health_check:
    endpoint: {{ $healthCheck }}
{{- end }}
receivers:
{{- if .Values.agent.collectLogs }}
  file_log:
    # User excludes and the self-ingestion excludes are merged here. Rendering
    # them in one place matters: a user exclude used to be dropped whenever
    # collectOtelLogs was true, because the whole key was inside that guard.
    {{- $exclude := concat (.Values.agent.fileLog.exclude | default list) (ternary (list) (list "/var/log/pods/*/otc-container/*.log" "/var/log/pods/*/otel-collector/*.log") (.Values.agent.collectOtelLogs | default false)) }}
    {{- if $exclude }}
    exclude:
      {{- toYaml $exclude | nindent 6 }}
    {{- end }}
    include:
      {{- toYaml (.Values.agent.fileLog.include | default (list "/var/log/pods/*/*/*.log")) | nindent 6 }}
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
  kubelet_stats:
    auth_type: {{ .Values.agent.kubeletStats.authType | default "serviceAccount" }}
    collection_interval: {{ .Values.agent.kubeletStats.collectionInterval | default "20s" }}
    endpoint: ${env:NODE_IP}:10250
    insecure_skip_verify: {{ ne .Values.agent.kubeletStats.insecureSkipVerify false }}
    {{- with .Values.agent.kubeletStats.caFile }}
    ca_file: {{ . }}
    {{- end }}
    # container is included deliberately, reversing an earlier decision to omit
    # it "to manage cardinality". It adds eleven default-on metrics per
    # container, which is the cost of being able to see which container in a pod
    # is consuming the pod's budget — the question a pod-level total cannot
    # answer. volume adds five per volume.
    metric_groups:
      {{- toYaml (.Values.agent.kubeletStats.metricGroups | default (list "node" "pod" "container" "volume")) | nindent 6 }}
{{- if .Values.agent.kubeletStats.usePodsEndpoint }}
    # Both of the blocks below make the receiver call the kubelet's /pods
    # endpoint in addition to /stats/summary: the scraper fetches pod metadata
    # when extra_metadata_labels is non-empty or when any limit/request
    # utilization metric is enabled. That call is not incremental — when it
    # fails the receiver returns no metrics at all for the interval, node and
    # pod metrics included, not merely the attributes it could not resolve.
    #
    # /pods authorizes against nodes/proxy, which this chart's ClusterRole
    # already grants. GKE Autopilot refuses to grant nodes/proxy at all, so on
    # Autopilot these must be turned off with
    # agent.kubeletStats.usePodsEndpoint=false or every scrape is lost.
    extra_metadata_labels: [k8s.volume.type]
    metrics:
      # Utilization against the container's own limits and requests, which is
      # what alerts are written on. Not emitted by default.
      k8s.container.cpu_limit_utilization:
        enabled: true
      k8s.container.cpu_request_utilization:
        enabled: true
      k8s.container.memory_limit_utilization:
        enabled: true
      k8s.container.memory_request_utilization:
        enabled: true
      # Pod-level equivalents. The limit variants are skipped by the receiver
      # for any pod where a container has no limit set.
      k8s.pod.cpu_limit_utilization:
        enabled: true
      k8s.pod.cpu_request_utilization:
        enabled: true
      k8s.pod.memory_limit_utilization:
        enabled: true
      k8s.pod.memory_request_utilization:
        enabled: true
{{- end }}
  host_metrics:
    root_path: /hostfs
    collection_interval: {{ .Values.agent.hostMetrics.collectionInterval | default "10s" }}
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
        # Without these every container overlay mount and kernel pseudo filesystem
        # on the node becomes its own series, which on a busy node is dozens per pod
        # and tells you nothing. fs_types is Prometheus node_exporter's default
        # fs-types-exclude set; mount_points is its default set plus the
        # Kubernetes-specific paths (kubelet, k3s containerd, snap). No official
        # OpenTelemetry chart ships an equivalent default. tmpfs is deliberately
        # kept, as node_exporter keeps it too: /run and friends are real usage worth
        # watching.
        exclude_mount_points:
          match_type: regexp
          mount_points:
            - '^/dev($|/)'
            - '^/proc($|/)'
            - '^/run/credentials($|/)'
            - '^/run/k3s/containerd($|/)'
            - '^/snap($|/)'
            - '^/sys($|/)'
            - '^/var/lib/containers/storage($|/)'
            - '^/var/lib/docker($|/)'
            - '^/var/lib/kubelet($|/)'
        exclude_fs_types:
          match_type: strict
          fs_types:
            - autofs
            - binfmt_misc
            - bpf
            - cgroup
            - cgroup2
            - configfs
            - debugfs
            - devpts
            - devtmpfs
            - erofs
            - fusectl
            - hugetlbfs
            - iso9660
            - mqueue
            - nsfs
            - overlay
            - proc
            - procfs
            - pstore
            - rpc_pipefs
            - securityfs
            - selinuxfs
            - squashfs
            - sysfs
            - tracefs
      load:
      memory:
        metrics:
          system.memory.limit:
            enabled: true
          system.memory.utilization:
            enabled: true
      {{- if .Values.agent.collectNetwork }}
      network:
      {{- end }}
      {{- if .Values.agent.collectProcesses }}
      processes:
      process:
        # Best effort: the agent reports the processes it can read on the node, and
        # per-process details it has no access to are left off rather than logged
        # once per process per scrape.
        mute_process_all_errors: true
        resource_attributes:
          # Emitted unconditionally, so it would be an empty string on every
          # process whose exe symlink the agent cannot read. command_line carries
          # the same information.
          process.executable.path:
            enabled: false
        metrics:
          process.uptime:
            enabled: true
      {{- end }}
  otlp:
    protocols:
      {{- with .Values.agent.otlp.grpcEndpoint }}
      grpc:
        endpoint: {{ . }}
      {{- end }}
      {{- with .Values.agent.otlp.httpEndpoint }}
      http:
        endpoint: {{ . }}
      {{- end }}

processors:
  {{- include "opentelemetry-kube-stack.batch" . | nindent 2 }}
{{- if .Values.resourceDetection.enabled }}
  {{- include "opentelemetry-kube-stack.resourceDetection" . | nindent 2 }}
{{- end }}
  k8s_attributes:
    extract:
      metadata:
        {{- include "opentelemetry-kube-stack.k8sAttributesMetadata" . | nindent 8 }}
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
  # Runs before enrichment in the pipelines: delta state is keyed on the full
  # resource, so a series that starts unenriched and later gains pod metadata
  # would look like a new series and lose a datapoint to initial_value: auto.
  cumulative_to_delta: {}
{{- if .Values.redaction.enabled }}
{{- if not .Values.redaction.config }}
{{- fail "redaction.enabled is true but redaction.config is empty. The processor's own default is allow_all_keys: false with no allowed_keys, which deletes every attribute it sees — including service.name and k8s.*. Provide rules, or leave redaction disabled." }}
{{- end }}
  # Runs after enrichment in the pipelines, so it also sees the attributes the
  # enrichment processors added. ignored_key_patterns is what keeps it from
  # masking the identity they set.
  redaction:
    {{- toYaml .Values.redaction.config | nindent 4 }}
{{- end }}
  resource:
    attributes:
      - key: k8s.cluster.name
        value: {{ include "opentelemetry-kube-stack.clusterName" . }}
        action: upsert
  # k8s.node.name for telemetry that arrives without one. insert, not upsert:
  # whatever already carries a node name keeps it. kubelet_stats sets it on its
  # node metric group, and k8s_attributes sets it for any pod it could
  # associate. What is left is host_metrics, which touches no pod so
  # k8s_attributes can never associate it, and records whose pod was not in the
  # informer cache. Those are this node's either way: the operator gives
  # daemonset collectors a Service with internalTrafficPolicy: Local, so OTLP
  # reaches the agent on the sender's own node. Upstream's kube-stack chart
  # does the same with resource_detection(k8s_api) and override: false.
  resource/node:
    attributes:
      - key: k8s.node.name
        value: ${env:K8S_NODE_NAME}
        action: insert
exporters:
{{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
{{- else }}
  {}
{{- end }}
connectors:
{{- if ne .Values.agent.spanMetrics.enabled false }}
  span_metrics:
    dimensions:
      {{- toYaml .Values.agent.spanMetrics.dimensions | nindent 6 }}
{{- end }}
service:
{{- if $healthCheck }}
  extensions:
    - health_check
{{- end }}
  pipelines:
    logs:
      receivers:
        - otlp
{{- if .Values.agent.collectLogs }}
        - file_log
{{- end }}
      processors:
        # memory_limiter must be first so load is shed before the pipeline
        # spends work enriching data it is about to reject; batch closes the
        # default list so it groups the finished records (user extraProcessors
        # are appended after it).
        - memory_limiter
{{- if .Values.resourceDetection.enabled }}
        - resource_detection
{{- end }}
        - k8s_attributes
        - resource
        - resource/node
{{- if .Values.redaction.enabled }}
        - redaction
{{- end }}
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
        - otlp_http/tsuga
        {{- end }}
    metrics:
      receivers:
        - otlp
        - kubelet_stats
{{- if ne .Values.agent.spanMetrics.enabled false }}
        - span_metrics
{{- end }}
        - host_metrics
      processors:
        - memory_limiter
        - cumulative_to_delta
{{- if .Values.resourceDetection.enabled }}
        - resource_detection
{{- end }}
        - k8s_attributes
        - resource
        - resource/node
{{- if .Values.redaction.enabled }}
        - redaction
{{- end }}
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
        - otlp_http/tsuga
        {{- end }}
    traces:
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
        - otlp_http/tsuga
        {{- end }}
        {{- if ne .Values.agent.spanMetrics.enabled false }}
        - span_metrics
        {{- end }}
      processors:
        - memory_limiter
{{- if .Values.resourceDetection.enabled }}
        - resource_detection
{{- end }}
        - k8s_attributes
        - resource
        - resource/node
{{- if .Values.redaction.enabled }}
        - redaction
{{- end }}
        - batch
      receivers:
        - otlp
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
