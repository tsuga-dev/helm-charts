{{- define "tsuga-otel.deamonset.config.default" -}}
extensions:
  health_check:
    endpoint: ${env:MY_POD_IP}:13133
receivers:
{{- if .Values.agent.collectLogs }}
  file_log:
  {{- if not .Values.agent.collectOtelLogs }}
    # Exclude the collector's own container logs to avoid a self-ingestion
    # feedback loop (the operator names the collector container "otc-container").
    exclude:
      - /var/log/pods/*/otc-container/*.log
      - /var/log/pods/*/otel-collector/*.log
  {{- end }}
    include:
      - /var/log/pods/*/*/*.log
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
    auth_type: serviceAccount
    collection_interval: 20s
    endpoint: ${env:NODE_IP}:10250
    insecure_skip_verify: true
    # Collect node and pod metrics (not container) to manage cardinality
    # Users can add 'container' to metric_groups if detailed container metrics are needed
    metric_groups: [node, pod]
    # Add volume type labels for storage observability
    extra_metadata_labels: [k8s.volume.type]
  host_metrics:
    root_path: /hostfs
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
        # Without these every overlayfs mount and kernel pseudo-filesystem on
        # the node becomes its own series, which on a busy node is dozens per
        # pod and tells you nothing. Uses upstream's fs_types, with anchored
        # mount-point regexes. tmpfs is deliberately kept: /run and friends are
        # real usage worth watching, and upstream keeps it too.
        exclude_mount_points:
          match_type: regexp
          mount_points:
            - '^/dev($|/)'
            - '^/proc($|/)'
            - '^/sys($|/)'
            - '^/run/k3s/containerd($|/)'
            - '^/var/lib/docker($|/)'
            - '^/var/lib/kubelet($|/)'
            - '^/snap($|/)'
        exclude_fs_types:
          match_type: strict
          fs_types:
            - autofs
            - binfmt_misc
            - bpf
            - cgroup2
            - configfs
            - debugfs
            - devpts
            - devtmpfs
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
  # Only wired into the node-local pipelines (metrics/node, logs/node). Those
  # receivers read this node's kernel and this node's log files, so the agent's
  # own node name is always the right answer. It is deliberately kept off the
  # otlp pipelines: otlp arrives over a Service that load-balances across every
  # agent, so a pod on another node reaches this collector and k8s_attributes
  # cannot associate it (filter.node_from_env_var restricts the pod informer to
  # local pods). Stamping there would label it with the receiving node.
  resource/node:
    attributes:
      - key: k8s.node.name
        value: ${env:K8S_NODE_NAME}
        action: upsert
  resource:
    attributes:
      - key: k8s.cluster.name
        value: {{ include "opentelemetry-kube-stack.clusterName" . }}
        action: upsert
exporters:
{{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
{{- else }}
  {}
{{- end }}
connectors:
  span_metrics:
    dimensions:
      - name: http.request.method
        default: GET
      - name: http.response.status_code
      - name: http.route
service:
  extensions:
    - health_check
  pipelines:
    logs:
      receivers:
        - otlp
      processors:
        # memory_limiter must be first so load is shed before the pipeline
        # spends work enriching data it is about to reject; batch last so it
        # groups the finished records.
        - memory_limiter
        - k8s_attributes
        - resource
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
        - otlp_http/tsuga
        {{- end }}
{{- if .Values.agent.collectLogs }}
    logs/node:
      receivers:
        - file_log
      processors:
        - memory_limiter
        - k8s_attributes
        - resource
        - resource/node
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
        - otlp_http/tsuga
        {{- end }}
{{- end }}
    metrics:
      receivers:
        - otlp
        # kubelet_stats sets k8s.node.name itself, so it needs no stamp.
        - kubelet_stats
        - span_metrics
      processors:
        - memory_limiter
        - k8s_attributes
        - resource
        - cumulativetodelta
        - batch
      exporters:
        {{- if ne (index .Values "tsuga" "enabledForDaemonset") false }}
        - otlp_http/tsuga
        {{- end }}
    metrics/node:
      receivers:
        - host_metrics
      processors:
        - memory_limiter
        - k8s_attributes
        - resource
        - resource/node
        - cumulativetodelta
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
        - span_metrics
      processors:
        - memory_limiter
        - k8s_attributes
        - resource
        - batch
      receivers:
        - otlp
  telemetry:
    {{- include "opentelemetry-kube-stack.otelTelemetry" . | nindent 4 }}
{{- end}}
