# opentelemetry-kube-stack

![Version: 0.11.3](https://img.shields.io/badge/Version-0.11.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1](https://img.shields.io/badge/AppVersion-v1-informational?style=flat-square)

A comprehensive Helm chart for OpenTelemetry Kubernetes operator with Tsuga integration, featuring dual deployment pattern (agent DaemonSet + cluster receiver), secure credential management, and production-ready configurations for telemetry collection to Tsuga platform.

**Homepage:** <https://tsuga-dev.github.io/helm-charts/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| OpenTelemetry Team | <antonin@tsuga.com> |  |

## Source Code

* <https://github.com/open-telemetry/opentelemetry-operator>
* <https://github.com/tsuga-dev/helm-charts>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
|  | otel-crds | 0.0.0 |
| https://open-telemetry.github.io/opentelemetry-helm-charts | opentelemetry-operator | 0.114.1 |

## Features

- **Dual Deployment Pattern**: Implements the recommended OpenTelemetry architecture with an agent (DaemonSet) and a cluster receiver (Deployment)
- **Agent (DaemonSet)**: Collects host metrics, kubelet metrics, container logs and application telemetry from each node
- **Cluster Receiver (Deployment)**: Collects cluster metrics, pod objects and Kubernetes Warning events from the API server
- **StatefulSet Collector + Target Allocator (optional)**: Scrapes Prometheus targets, sharded across replicas (`targetAllocator.enabled`)
- **Secret Management**: Configurable secrets for OpenTelemetry configuration with external secret support
- **RBAC Support**: Comprehensive service account and role-based access control
- **Resource Management**: Configurable resource limits and requests for both components
- **Host Metrics Collection**: Built-in support for node-level metrics collection
- **Kubernetes Objects Monitoring**: Watches pod objects, and optionally Warning events
- **Comprehensive Observability**: Logs, metrics, and traces collection with intelligent defaults
- **Security First**: Built-in security best practices and credential management
- **Production Ready**: Optimized configurations for production environments
- **Flexible Configuration**: Chart values for the common settings, `extraReceivers`/`extraProcessors`/`extraExporters` to add components, or `customConfig` to replace a collector's configuration outright

## Architecture

The chart deploys two collectors by default, plus a third that is opt-in:

### Agent (DaemonSet)

- Runs on every node in the cluster
- Collects host metrics, kubelet metrics, container logs and application telemetry from its own node
- Exports directly to Tsuga. There is no agent-to-cluster-receiver hop — the collectors are independent and each exports on its own.
- Uses host networking for optimal performance (configurable)

**Default Receivers:**
- **Host Metrics** (`host_metrics`): CPU, memory, disk, filesystem, load, paging, and optionally network and process metrics. The whole scraper map is `agent.hostMetrics.scrapers` and is rendered into the receiver as given, so every option the upstream scrapers accept is settable from values and setting a scraper to `null` drops it; `agent.collectNetwork` and `agent.collectProcesses` gate whether those scrapers render at all, independently of what the map configures for them. Kernel pseudo filesystems, container overlay filesystems and whatever is mounted under the container and kubelet state directories are excluded to keep series counts down. One consequence worth knowing: excluding `overlay` also drops the root filesystem series on nodes whose `/` is itself an overlay mount, which means kind and k3d — cloud nodes are unaffected. `agent.collectProcesses=true` adds the `process`/`processes` scrapers, which report every process on the node; a few details such as the executable path and owner are left off where the agent has no access to them.
- **Kubelet Stats** (`kubelet_stats`): Node, pod, container and volume metrics, plus the eight limit/request utilization metrics. The groups collected are configurable via `agent.kubeletStats.metricGroups` — `container` and `volume` are the expensive ones, eleven metrics per container and five per volume. The utilization metrics and the `k8s.volume.type` label both require the kubelet `/pods` endpoint, which authorizes against `nodes/proxy`; when that call fails the receiver discards the whole scrape, so `agent.kubeletStats.usePodsEndpoint=false` exists for clusters that cannot grant it (GKE Autopilot).
- **OTLP**: Receives traces, metrics, and logs over gRPC (`:4317`) and HTTP (`:4318`)
- **File Logs** (`file_log`): Collects container logs from `/var/log/pods/*/*/*.log` (controlled by `agent.collectLogs`)

**Default Processors:**
- **Memory Limiter**: Prevents memory issues (80% limit, 25% spike limit). First in every default pipeline, so load is shed before the pipeline spends work on data it is about to reject.
- **Cumulative To Delta**: Converts cumulative counters to delta. Wired into the metrics pipeline only, and placed before enrichment: delta state is keyed on the full resource, so a series that starts unenriched and later gains pod metadata would look like a brand-new series and lose a datapoint.
- **Resource Detection** (`resource_detection`): Adds cloud and host attributes (`cloud.provider`, `cloud.region`, `host.id`). **Off by default** — enable with `resourceDetection.enabled=true`. When enabled it runs first among the enrichment processors, in every pipeline.
- **K8s Attributes** (`k8s_attributes`): Enriches telemetry with Kubernetes metadata and selected pod labels/annotations. The attribute list is configurable via `k8sAttributes.metadata`.
- **Resource**: Adds `k8s.cluster.name` to everything
- **Resource/node** (`resource/node`): Adds `k8s.node.name` from the downward API with action `insert`, so it only writes when the attribute is missing and anything that already carries a node name keeps it. `kubelet_stats` sets it on its node metric group and `k8s_attributes` sets it for every pod it could associate; what is left is `host_metrics`, which reads the node's kernel and touches no pod so `k8s_attributes` can never associate it, plus records whose pod missed the informer cache. Those all belong to this node: the operator gives `daemonset` collectors a Service with `internalTrafficPolicy: Local`, so OTLP sent to the agent Service reaches the agent on the sender's own node.
- **Redaction** (`redaction`): Masks credentials in attributes and log bodies. **Off by default** — enable with `redaction.enabled=true`. Runs after the enrichment processors and before `batch`, in every pipeline, so it also sees what enrichment added. See [Redaction](#redaction).
- **Batch**: Batches telemetry for efficient processing (`send_batch_size`/`send_batch_max_size` = 5000). Last in every default pipeline. User `extraProcessors` are appended after the default list, so anything you add runs on already-batched data.

**Default Connectors:**
- **Span Metrics** (`span_metrics`): Generates RED metrics from spans (see dimensions below). Note the underscored type name — the canonical name at this chart's collector floor. Disable with `agent.spanMetrics.enabled=false`.

**Default Exporters:**
- **otlp_http/tsuga**: Forwards all telemetry to the Tsuga endpoint with authentication (enabled unless `tsuga.enabledForDaemonset=false`)

**Service Pipelines:**
- **Logs**: `otlp` (+`file_log` when `agent.collectLogs`) → `memory_limiter`, [`resource_detection`], `k8s_attributes`, `resource`, `resource/node`, [`redaction`], `batch` → `otlp_http/tsuga`
- **Metrics**: `otlp`, `kubelet_stats`, [`span_metrics`], `host_metrics` → `memory_limiter`, `cumulative_to_delta`, [`resource_detection`], `k8s_attributes`, `resource`, `resource/node`, [`redaction`], `batch` → `otlp_http/tsuga`
- **Traces**: `otlp` → `memory_limiter`, [`resource_detection`], `k8s_attributes`, `resource`, `resource/node`, [`redaction`], `batch` → `otlp_http/tsuga`, [`span_metrics`]

Components in [brackets] are conditional: `resource_detection` appears only when `resourceDetection.enabled=true`, `redaction` only when `redaction.enabled=true`, and `span_metrics` only while `agent.spanMetrics.enabled` is true.

Collector self-telemetry is configured under `service::telemetry` rather than in a pipeline, and is pushed to Tsuga by the collector's own embedded SDK. Bypassing the pipelines is deliberate: it means these metrics still arrive when a pipeline is wedged, which is when they matter most. Because supplying a reader replaces the collector's default one, nothing is served on `:8888`. See [docs/collector-internal-metrics.md](docs/collector-internal-metrics.md).

**Default Spanmetrics Dimensions:**
- `http.request.method`
- `http.response.status_code`
- `http.route`

`http.route` is preferred over raw URL/path attributes because it represents the logical route template and keeps metric cardinality under control. URL-like attributes such as `http.url`, `url.full`, `http.path`, and `http.target` are intentionally excluded from the default metric dimensions because they fragment metrics with IDs, query strings, and other request-specific values.

This default targets modern OpenTelemetry HTTP semantic conventions and is most useful for server spans. If your workloads still emit legacy attributes such as `http.method` and `http.status_code`, or if you want client-focused dependency metrics, replace the dimensions with `agent.spanMetrics.dimensions`.

Example for client-oriented HTTP dependency metrics:

```yaml
agent:
  spanMetrics:
    dimensions:
      - name: http.request.method
        default: GET
      - name: http.response.status_code
      - name: server.address
```

Example for workloads still emitting legacy HTTP semantic conventions:

```yaml
agent:
  spanMetrics:
    dimensions:
      - name: http.method
        default: GET
      - name: http.status_code
      - name: http.route
```

> **`extraReceivers` and friends can only add components, not retune existing ones.** They are merged with the chart defaults winning on any conflicting key, so a value you set for a component the chart already defines is silently discarded. Use the dedicated chart values above to change a default, or `customConfig` to replace a collector's configuration wholesale.

### Cluster Receiver (Deployment)

- Collects cluster metrics and events using the Kubernetes API server
- **Pinned to a single replica.** `k8s_cluster` and `k8s_objects` do not use leader election here, so a second replica would report the same cluster state again: every cluster metric counted twice and every object ingested twice. The operator's CRD already defaults to 1; the chart sets it explicitly so a `kubectl scale` does not survive a `helm upgrade`.

**Default Receivers:**
- **Kubernetes Cluster** (`k8s_cluster`): Collects cluster-level metrics and entity events
- **Kubernetes Objects** (`k8s_objects`): Watches pod objects only (enabled by default, disable with `cluster.collectk8sobjects=false`)
- **Kubernetes Warning Events** (`k8s_objects/events`): Watches `events.k8s.io` filtered to `type=Warning` at the API server. **Off by default** — enable with `cluster.collectk8sevents=true`. A second receiver instance, so events can set `include_initial_state: false` while the pods stream keeps its snapshot.

**Default Processors:**
- **Memory Limiter**: Prevents memory issues (80% limit, 25% spike limit). First in every default pipeline.
- **Resource Detection** (`resource_detection`): As on the agent. Off by default.
- **K8s Attributes**: Enriches telemetry with Kubernetes metadata and selected pod labels/annotations
- **Transform** (`transform/k8s_event_severity`): Sets `WARN` severity on event records. Only present when `cluster.collectk8sevents=true`, and only in the events pipeline — `k8s_objects` sets no severity, and a missing level would be normalized to `INFO`.
- **Resource**: Adds `k8s.cluster.name`
- **Batch**: Batches telemetry for efficient processing. Last in every default pipeline; user `extraProcessors` are appended after it.

There is no `cumulative_to_delta` in this collector. `k8s_cluster` emits gauges and non-monotonic sums, and the processor only converts monotonic sums, histograms and exponential histograms, so there is nothing for it to convert.

**Default Exporters:**
- **otlp_http/tsuga**: Forwards to the Tsuga endpoint (enabled unless `tsuga.enabledForClusterReceiver=false`)

**Service Pipelines:**
- **Metrics**: `k8s_cluster` → `memory_limiter`, [`resource_detection`], `k8s_attributes`, `resource`, `batch` → `otlp_http/tsuga`
- **Entity Events (Logs)**: `k8s_cluster` (+`k8s_objects` when enabled) → `memory_limiter`, [`resource_detection`], `k8s_attributes`, `resource`, `batch` → `otlp_http/tsuga`
- **Warning Events (`logs/events`)**: `k8s_objects/events` → `memory_limiter`, [`resource_detection`], `transform/k8s_event_severity`, `resource`, `batch` → `otlp_http/tsuga`. Only rendered when `cluster.collectk8sevents=true`. `k8s_attributes` is deliberately absent: a `k8s_objects` watch record carries only `k8s.namespace.name`, which none of the configured `pod_association` sources can match.

Components in [brackets] are conditional, as above.

### StatefulSet Collector + Target Allocator (optional)

Disabled by default; enable with `targetAllocator.enabled=true`. Intended for Prometheus scraping, where the Target Allocator shards scrape jobs across collector replicas so no two replicas scrape the same target.

- **Receiver**: `prometheus`, with its scrape config supplied by the Target Allocator at runtime. The static config in the chart is a placeholder the allocator replaces.
- **Processors**: `memory_limiter`, `cumulative_to_delta`, [`resource_detection`], `k8s_attributes`, `resource`, `batch`
- **Exporter**: `otlp_http/tsuga` (unless `tsuga.enabledForStatefulset=false`)
- **Replicas**: `statefulset.replicas` (default 1). Unlike the cluster receiver this is safe to scale, because the allocator partitions the targets.
- **Discovery**: set `targetAllocator.spec.prometheusCR.enabled=true` to pick up `ServiceMonitor`/`PodMonitor` resources. This requires those CRDs to exist in the cluster, i.e. prometheus-operator.
- **Scrape interval**: `statefulset.scrapeInterval` (default `30s`) sets both the scrape interval and how often the collector refreshes its target list.

## Quick Start

Use the deploy script

```bash
./deploy.sh
```

## Prerequisites

Before installing this chart, you need the following components:

### 1. cert-manager (Required)

The OpenTelemetry Operator requires cert-manager to be installed in your cluster.

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
```

Verify cert-manager is running:
```bash
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s
```

### 2. OpenTelemetry Operator (Required)

The OpenTelemetry Operator is required for auto-instrumentation features. You have two options:

#### Option A: Install with this chart (recommended)

This chart includes the OpenTelemetry Operator as a dependency. Enable it in your values:

```yaml
opentelemetry-operator:
  enabled: true
```

Or via command line:
```bash
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --set clusterName="<CLUSTER_NAME>" \
  --set opentelemetry-operator.enabled=true
```

#### Option B: Install separately

If you prefer to manage the operator separately or it's already installed:

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

Verify the operator is running:
```bash
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=opentelemetry-operator -n opentelemetry-operator-system --timeout=300s
```

## Installation

`clusterName` is required on every install: it is what distinguishes this cluster's
telemetry from every other cluster's in Tsuga.

## Auto-instrumentation (APM)

This chart can optionally create an OpenTelemetry Operator `Instrumentation` resource via `autoInstrumentation`.

### Prerequisites

- The **OpenTelemetry Operator** must be installed in the cluster (see prerequisites section above).
- **cert-manager** must be installed in the cluster.
- Your workloads must opt-in via **pod annotations** (examples below).

### Enable and configure

Create an `Instrumentation` CR with your desired configuration:

```yaml
autoInstrumentation:
  enabled: true
  # apiVersion depends on your operator version
  apiVersion: opentelemetry.io/v1alpha1
  spec:
    exporter:
      # The operator injects OTEL_NODE_IP into every instrumented container, so
      # each pod reaches the agent running on its own node.
      endpoint: http://$(OTEL_NODE_IP):4318
    propagators: [tracecontext, baggage]
    sampler:
      type: parentbased_traceidratio
      argument: "1.0"
    # Configure the language(s) you plan to inject
    java:
      image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.10.0
```

### Inject into workloads

Annotate your workload pods to enable injection:

```yaml
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-java: "true"
```

Supported annotation keys depend on language (examples):

- `instrumentation.opentelemetry.io/inject-java`
- `instrumentation.opentelemetry.io/inject-python`
- `instrumentation.opentelemetry.io/inject-nodejs`
- `instrumentation.opentelemetry.io/inject-dotnet`

### Install the Chart

#### Option 1: Using Chart Repository (Recommended)

```bash
# Add the repository
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
helm repo update

# Install with Tsuga configuration
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --set clusterName="<CLUSTER_NAME>" \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" \
  --set tsuga.apiKey="<TSUGA_API_KEY>"
```

#### Option 2: Direct Installation

```bash
# Install directly from the chart directory
helm install my-otel-stack ./opentelemetry-kube-stack \
  --set clusterName="<CLUSTER_NAME>" \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" \
  --set tsuga.apiKey="<TSUGA_API_KEY>"
```

#### Option 3: Using Values File

```bash
# Create a values file
cat > my-values.yaml << EOF
clusterName: "<CLUSTER_NAME>"
tsuga:
  otlpEndpoint: "https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp"
  apiKey: "<TSUGA_API_KEY>"
secret:
  create: true
EOF

# Install with values file
helm install my-otel-stack ./opentelemetry-kube-stack -f my-values.yaml
```

## Redaction

The agent can mask credentials before telemetry leaves the cluster, using the collector [`redaction` processor](https://app.tsuga.com/documentation/data-collection/guides/how-to-use-the-opentelemetry-redaction-processor). It is off by default:

```yaml
redaction:
  enabled: true
```

The rules are documented at `redaction.config` in [values.yaml](values.yaml). Validate them against your own telemetry with `summary: debug`, which names the keys it changed, then set it back to `silent`: at `info` and above the processor stamps `redaction.*.count` on every record it touches, which on metrics splits the series.

Three things to know before extending them. `url_sanitizer` and `db_sanitizer` are left off deliberately — their `attributes` lists scope span and metric attributes only, so on a logs pipeline they rewrite the whole log body rather than the URLs and queries in it. `redaction` is a processor name this chart now owns, so an existing `agent.config.extraProcessors.redaction` is silently replaced, and also listing it in a pipeline's `extraProcessors` makes the collector reject the config as a duplicate. And `hash_function: hmac-sha256` with `hmac_key: ${env:REDACTION_HMAC_KEY}` hashes instead of masking, which keeps values correlatable; supply the key (32 bytes minimum) through `agent.extraEnvs`.

> **Note:** Tsuga's [sensitive data scanner](https://app.tsuga.com/documentation/process/sensitive-data-scanner) keeps these rules in the platform instead of in every collector, but runs at ingest — so it covers logs only, cannot reach logs already stored, and does not stop the raw value leaving the cluster. Use it alongside collector redaction rather than instead of it.

## Configuration

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | {} | Affinity rules applied to every collector. Overridden per collector by agent.affinity, cluster.affinity or statefulset.affinity. |
| agent.addLogsVolumes | bool | true | Mount the /var/log/pods and /var/lib/docker/containers hostPaths even when collectLogs is false. Has no effect while collectLogs is true, which already mounts them. |
| agent.affinity | object | {} | Agent-specific affinity rules. If not set, inherits from global affinity configuration. |
| agent.collectLogs | bool | true | Collect logs from the host and containers. When true, enables the file_log receiver to collect logs from /var/log/pods. Also mounts required volumes for log collection. |
| agent.collectNetwork | bool | false | Collect host network metrics. When true, enables network scraper in the host_metrics receiver. |
| agent.collectOtelLogs | bool | false | Collect OpenTelemetry collector logs. When false (default), excludes the collector's own container logs to avoid a self-ingestion feedback loop that produces container-parser errors. |
| agent.collectProcesses | bool | false | Collect host processes metrics. When true, enables processes and process scrapers in the host_metrics receiver. |
| agent.config | object | `{"extraConnectors":{},"extraExporters":{},"extraExtensions":{},"extraProcessors":{},"extraReceivers":{},"service":{"extraExtensions":[],"pipelines":{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | Agent collector configuration (merge-based approach). Use this to extend the default configuration. Default receivers: file_log (when agent.collectLogs), kubelet_stats, host_metrics, otlp. Default processors: memory_limiter, cumulative_to_delta, resource_detection (when resourceDetection.enabled), k8s_attributes, resource, resource/node, batch. Default connectors: span_metrics (when agent.spanMetrics.enabled). Default extensions: health_check (when agent.healthCheckEndpoint is set). |
| agent.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration. These are merged with default connectors. |
| agent.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration. These are merged with default exporters (otlp_http/tsuga). |
| agent.config.extraExtensions | object | {} | Additional extensions to merge into the collector configuration. These are merged with the default health_check extension, which is present only when agent.healthCheckEndpoint is set. |
| agent.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration. These are merged with default processors. |
| agent.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration. These are merged with default receivers. |
| agent.config.service.extraExtensions | list | [] | Additional extensions to add to the service configuration. Added after the default health_check extension, which is present only when agent.healthCheckEndpoint is set. |
| agent.config.service.pipelines.extraPipelines | object | {} | Additional pipelines to add to the service configuration. These are completely new pipelines, not extensions of the default ones. |
| agent.config.service.pipelines.logs.extraExporters | list | [] | Additional exporters to add to the logs pipeline. Added to default exporter (otlp_http/tsuga). |
| agent.config.service.pipelines.logs.extraProcessors | list | [] | Additional processors to add to the logs pipeline. Added to default processors (memory_limiter, k8s_attributes, resource, resource/node, batch). |
| agent.config.service.pipelines.logs.extraReceivers | list | [] | Additional receivers to add to the logs pipeline. Added to default receivers (otlp, file_log). |
| agent.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline. Added to default exporter (otlp_http/tsuga). |
| agent.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline. Added to default processors (memory_limiter, cumulative_to_delta, k8s_attributes, resource, resource/node, batch). |
| agent.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline. Added to default receivers (otlp, kubelet_stats, span_metrics, host_metrics). |
| agent.config.service.pipelines.traces.extraExporters | list | [] | Additional exporters to add to the traces pipeline. Added to default exporters (otlp_http/tsuga, span_metrics). |
| agent.config.service.pipelines.traces.extraProcessors | list | [] | Additional processors to add to the traces pipeline. Added to default processors (memory_limiter, k8s_attributes, resource, resource/node, batch). |
| agent.config.service.pipelines.traces.extraReceivers | list | [] | Additional receivers to add to the traces pipeline. Added to default receivers (otlp). |
| agent.customConfig | object | {} | Replace default config with complete custom configuration. When set, this completely replaces the default collector configuration. Use this for full control over the OpenTelemetry Collector config See cluster.customConfig for example format. |
| agent.enabled | bool | true | Deploy the agent, a DaemonSet with one pod per node. It collects host metrics, kubelet metrics and pod logs, and is the OTLP endpoint instrumented applications send to, so turning it off removes all four. |
| agent.extraAnnotationsMapping | list | [] | Annotations mapping configuration for agent. Maps Kubernetes pod annotations to OpenTelemetry resource attributes. These are appended to default annotation mappings. Same shape as agent.extraLabelMapping. |
| agent.extraEnvs | list | [] | Extra environment variables for the agent. Added after the variables the chart injects automatically: MY_POD_IP, NODE_IP, POD_NAME, POD_UID and K8S_NODE_NAME, plus TSUGA_API_KEY and TSUGA_OTLP_ENDPOINT while any collector exports to Tsuga. |
| agent.extraLabelMapping | list | [] | Label mapping configuration for agent. Maps Kubernetes pod labels to OpenTelemetry resource attributes. These are appended to default label mappings. Format: List of objects with tag_name, key, and from fields, where from is one of `pod`, `namespace`, `node`, `deployment`, `statefulset`, `daemonset`, `job` and defaults to `pod`. |
| agent.fileLog | object | `{"exclude":[],"include":["/var/log/pods/*/*/*.log"]}` | file_log receiver paths (used when collectLogs is true). |
| agent.fileLog.exclude | list | [] | Log file globs to skip. Narrowing this is the biggest log-cost lever in the chart: excluding a noisy namespace, e.g. `/var/log/pods/kube-system_*/*/*.log`, drops those records before they are ever read. |
| agent.fileLog.include | list | ["/var/log/pods/*/*/*.log"] | Log file globs to read. |
| agent.healthCheckEndpoint | string | "${env:MY_POD_IP}:13133" | Address for the health_check extension, which backs the liveness probe. Set to "" to omit the extension, and the liveness probe with it. |
| agent.hostMetrics | object | see values.yaml | host_metrics receiver options. |
| agent.hostMetrics.collectionInterval | string | "10s" | How often to collect host metrics, e.g. `60s`. Datapoint volume scales inversely, so 60s costs a sixth of 10s. |
| agent.hostMetrics.scrapers | object | see values.yaml | host_metrics scrapers, rendered verbatim into the receiver config. Setting a scraper to `null` drops it. See the [receiver docs](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/hostmetricsreceiver/README.md) for the options each scraper accepts. |
| agent.hostNetwork | bool | true | Run the agent in the host network namespace, so its OTLP ports are reachable at the node's own IP. Those ports then bind on the node, so anything already holding 4317 or 4318, another monitoring agent or a second collector DaemonSet, makes the pod crash-loop until agent.otlp is repointed. Set it false where the node network namespace is not available to pods. |
| agent.image | string | "" | Overrides the top-level image for the agent only. |
| agent.kubeletStats | object | `{"authType":"serviceAccount","caFile":"","collectionInterval":"20s","insecureSkipVerify":true,"metricGroups":["node","pod","container","volume"],"usePodsEndpoint":true}` | kubelet_stats receiver options. |
| agent.kubeletStats.authType | string | "serviceAccount" | Kubelet authentication method. One of `serviceAccount`, `tls`, `kubeConfig`, `none`. |
| agent.kubeletStats.caFile | string | "" | CA bundle path used to verify the kubelet, e.g. `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`. Requires insecureSkipVerify to be false, and the file to be mounted in the pod. |
| agent.kubeletStats.collectionInterval | string | "20s" | How often to collect kubelet metrics, e.g. `60s`. Datapoint volume scales inversely, so 60s costs a sixth of 10s. |
| agent.kubeletStats.insecureSkipVerify | bool | true | Skip verification of the kubelet's serving certificate. |
| agent.kubeletStats.metricGroups | list | [node, pod, container, volume] | Kubelet metric groups to collect. Any of `node`, `pod`, `container`, `volume`. node and pod are the minimum useful set; container adds eleven metrics per container and volume five per volume, so those two drive kubelet metric cardinality. |
| agent.kubeletStats.usePodsEndpoint | bool | true | Use the kubelet /pods endpoint for pod metadata. It is what supplies the volume type labels and the eight limit/request utilization metrics, and it authorizes against the nodes/proxy subresource: a failing call discards the whole scrape, not just those attributes, so set this false on clusters that cannot grant nodes/proxy, GKE Autopilot in particular. |
| agent.nodeSelector | object | {} | Agent-specific node selector. If not set, inherits from global nodeSelector configuration. |
| agent.otlp | object | `{"grpcEndpoint":"${env:MY_POD_IP}:4317","httpEndpoint":"${env:MY_POD_IP}:4318"}` | OTLP receiver listen addresses. |
| agent.otlp.grpcEndpoint | string | "${env:MY_POD_IP}:4317" | gRPC listen address. Set to "" to disable the gRPC protocol. |
| agent.otlp.httpEndpoint | string | "${env:MY_POD_IP}:4318" | HTTP listen address. Set to "" to disable the HTTP protocol. Emptying both endpoints leaves the otlp receiver with no protocol, which the collector rejects at startup. |
| agent.resources | object | {} | Resource limits and requests for the agent. Replaces the top-level resources block wholesale rather than merging, so a partial override drops whatever it does not restate. |
| agent.spanMetrics | object | `{"aggregationTemporality":"AGGREGATION_TEMPORALITY_DELTA","dimensions":[{"default":"GET","name":"http.request.method"},{"name":"http.response.status_code"},{"name":"http.route"}],"enabled":true}` | span_metrics connector options (RED metrics generated from spans). |
| agent.spanMetrics.aggregationTemporality | string | AGGREGATION_TEMPORALITY_DELTA | Aggregation temporality of the generated metrics. Delta drops a series once its spans stop; cumulative keeps re-exporting the last value forever, which cumulative_to_delta then reads as an endless run of zeros. |
| agent.spanMetrics.dimensions | list | see values.yaml | Span attributes to keep as metric dimensions. `default` supplies a value when the attribute is absent. |
| agent.spanMetrics.enabled | bool | true | Generate request count and duration metrics from spans, one series per service and per combination of the dimensions below. Disabling it removes those metrics; the spans themselves are unaffected. |
| agent.tolerations | list | [] | Agent-specific tolerations. If not set, inherits from global tolerations configuration. |
| autoInstrumentation.annotations | object | {} | Extra annotations to add to the Instrumentation resource. |
| autoInstrumentation.apiVersion | string | "opentelemetry.io/v1alpha1" | apiVersion for the Instrumentation CR. The CR is v1alpha1 on current operator releases. |
| autoInstrumentation.enabled | bool | false | Enable OpenTelemetry Operator auto-instrumentation (Instrumentation CR). Requires the OpenTelemetry Operator to be installed in the cluster. |
| autoInstrumentation.labels | object | {} | Extra labels to add to the Instrumentation resource. |
| autoInstrumentation.nameOverride | string | "" | Override the name of the Instrumentation resource. If empty, defaults to "<release-fullname>-instrumentation". |
| autoInstrumentation.spec | object | {} | Instrumentation spec (full passthrough). This is passed directly to the Instrumentation Custom Resource spec. It can include, among others, exporter, propagators, sampler, env, resource, and language blocks such as java, nodejs, python, dotnet, go and apacheHttpd. The empty default creates an Instrumentation with no exporter endpoint, so set spec.exporter.endpoint to the agent's OTLP address before annotating a workload. Ref: https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#instrumentation |
| batch.sendBatchMaxSize | int | 5000 | Hard cap on items per batch. Lower this if the backend rejects large requests. Keeping it equal to sendBatchSize means a timeout can never build an oversized batch. |
| batch.sendBatchSize | int | 5000 | Item count that triggers a send. |
| batch.timeout | string | "" | Maximum time to wait before sending an undersized batch, e.g. `5s`. Empty uses the processor's own default of 200ms. |
| cluster.affinity | object | {} | Cluster-specific affinity rules. If not set, inherits from global affinity configuration. |
| cluster.allocatableTypesToReport | list | [cpu, memory, ephemeral-storage] | Names from the node's `status.allocatable`, such as `cpu`, `memory`, `ephemeral-storage` and `pods`. A name the node does not report, `storage` for example, is skipped silently. |
| cluster.collectionInterval | string | "10s" | How often to collect cluster metrics, e.g. `30s`. Datapoint volume scales inversely, so 60s costs a sixth of 10s. |
| cluster.collectk8sevents | bool | false | Collect Kubernetes Warning events as logs. Events are the only source for OOMKilled, FailedScheduling, Evicted, ErrImagePull, FailedMount and failing probes, since no metric receiver reports them. Off by default because the volume follows cluster health. Only Warning events are collected, filtered at the API server, so Normal events are never transferred. |
| cluster.collectk8sobjects | bool | true | Watch pod objects and send them as logs. Powers the Kubernetes view, which uses them to show pod configuration. Costs one log record per pod change, plus a full snapshot of every pod on each collector restart. |
| cluster.config | object | `{"extraConnectors":{},"extraExporters":{},"extraProcessors":{},"extraReceivers":{},"service":{"extraExtensions":[],"pipelines":{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | Cluster receiver configuration (merge-based approach). Use this to extend the default configuration. Default receivers: k8s_cluster, k8s_objects (when cluster.collectk8sobjects), k8s_objects/events (when cluster.collectk8sevents). Default processors: memory_limiter, batch, resource_detection (when resourceDetection.enabled), transform/k8s_event_severity (when cluster.collectk8sevents), k8s_attributes, resource. Default extensions: health_check (when cluster.healthCheckEndpoint is set). |
| cluster.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration. These are merged with default connectors. |
| cluster.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration. These are merged with default exporters (otlp_http/tsuga). |
| cluster.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration. These are merged with default processors (memory_limiter, batch, k8s_attributes, resource, plus resource_detection when resourceDetection.enabled and transform/k8s_event_severity when cluster.collectk8sevents). |
| cluster.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration. These are merged with default receivers (k8s_cluster, plus k8s_objects when cluster.collectk8sobjects and k8s_objects/events when cluster.collectk8sevents). |
| cluster.config.service.extraExtensions | list | [] | Additional extensions to add to the service configuration. Added after the default health_check extension, which is present only when cluster.healthCheckEndpoint is set. |
| cluster.config.service.pipelines.extraPipelines | object | {} | Additional pipelines to add to the service configuration. These are completely new pipelines, not extensions of the default ones. |
| cluster.config.service.pipelines.logs | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Logs pipeline configuration (Kubernetes entity events). |
| cluster.config.service.pipelines.logs.extraExporters | list | [] | Additional exporters to add to the logs pipeline. Added to default exporter (otlp_http/tsuga). |
| cluster.config.service.pipelines.logs.extraProcessors | list | [] | Additional processors to add to the logs pipeline. Added to default processors (memory_limiter, k8s_attributes, resource, batch). |
| cluster.config.service.pipelines.logs.extraReceivers | list | [] | Additional receivers to add to the logs pipeline. Added to default receivers (k8s_cluster, plus k8s_objects when cluster.collectk8sobjects). |
| cluster.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline. Added to default exporter (otlp_http/tsuga). |
| cluster.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline. Added to default processors (memory_limiter, k8s_attributes, resource, batch). |
| cluster.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline. Added to default receiver (k8s_cluster). |
| cluster.customConfig | object | {} | Replace default config with complete custom configuration. When set, this completely replaces the default collector configuration. Use this for full control over the OpenTelemetry Collector config. |
| cluster.enabled | bool | true | Deploy the cluster receiver, a single-replica Deployment that reads cluster-level metrics, pod objects and Warning events from the API server. The agent collects none of those, so turning it off loses them. |
| cluster.extraAnnotationsMapping | list | [] | Annotations mapping configuration for the cluster receiver. Maps Kubernetes pod annotations to OpenTelemetry resource attributes. These are appended to default annotation mappings. Same shape as agent.extraLabelMapping. |
| cluster.extraEnvs | list | [] | Extra environment variables for the cluster receiver. Added after the variables the chart injects automatically: MY_POD_IP, NODE_IP, POD_NAME, POD_UID and K8S_NODE_NAME, plus TSUGA_API_KEY and TSUGA_OTLP_ENDPOINT while any collector exports to Tsuga. |
| cluster.extraLabelMapping | list | [] | Label mapping configuration for the cluster receiver. Maps Kubernetes pod labels to OpenTelemetry resource attributes. These are appended to default label mappings. Same shape as agent.extraLabelMapping. |
| cluster.healthCheckEndpoint | string | "${env:MY_POD_IP}:13133" | Address for the health_check extension, which backs the liveness probe. Set to "" to omit the extension, and the liveness probe with it. |
| cluster.image | string | "" | Overrides the top-level image for the cluster receiver only. |
| cluster.nodeConditionsToReport | list | [Ready, MemoryPressure, DiskPressure, PIDPressure] | Node conditions reported as metrics. Any condition type works, so `NetworkUnavailable` or the custom conditions node-problem-detector writes can be added. A name no node reports emits a permanent -1 gauge rather than nothing, so check the spelling. |
| cluster.nodeSelector | object | {} | Cluster-specific node selector. If not set, inherits from global nodeSelector configuration. |
| cluster.resources | object | {} | Resource limits and requests for the cluster receiver. Replaces the top-level resources block wholesale rather than merging, so a partial override drops whatever it does not restate. |
| cluster.tolerations | list | [] | Cluster-specific tolerations. If not set, inherits from global tolerations configuration. |
| clusterName | string | "" (must be set) | REQUIRED. Name of the cluster, attached to all telemetry as k8s.cluster.name. The install fails while this is empty and any collector is rendering the chart's default config. |
| fullnameOverride | string | "" | Override the full name used in resource naming. |
| image | string | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.157.0"` | Collector image used by all three collectors. Must be v0.157.0 or newer: the default config uses the cumulative_to_delta processor, and the chart fails the render on an older tag. Keep the tag, because an untagged image resolves to :latest and skips that check. |
| k8sAttributes.metadata | list | see values.yaml | Kubernetes metadata to attach to telemetry. Dropping `k8s.pod.name` and `k8s.pod.uid` is the largest cardinality saving available here, at the cost of per-pod identification. An unsupported field name fails the collector at startup. |
| nameOverride | string | "" | Override the chart name used in resource naming. |
| nodeSelector | object | {} | Node selector applied to every collector. Overridden per collector by agent.nodeSelector, cluster.nodeSelector or statefulset.nodeSelector. |
| opentelemetry-operator.admissionWebhooks.failurePolicy | string | `"Ignore"` | Failure policy for the operator's admission webhooks. `Ignore` lets the operator and the custom resources it manages be installed in the same pass. |
| opentelemetry-operator.crds.create | bool | `false` | Let the operator subchart install the CRDs. Keep this false: it races with helm, and this chart ships the CRDs through its own otel-crds dependency instead. |
| opentelemetry-operator.enabled | bool | `false` | Install the OpenTelemetry Operator and its CRDs as subchart dependencies. Leave this false when the operator is already installed in the cluster; the custom resources this chart creates need it either way. |
| opentelemetry-operator.manager.collectorImage.repository | string | `"otel/opentelemetry-collector-k8s"` | Collector image repository the operator falls back to for any OpenTelemetryCollector that does not set an image of its own. This chart always sets one, so it applies only when the top-level image is "". |
| rbac.create | bool | true | Create the ClusterRole and ClusterRoleBinding the collectors need to read Kubernetes state. Without them kubelet_stats, k8s_cluster, k8s_objects and k8s_attributes are all denied by the API server. |
| redaction.config | object | see values.yaml | Redaction processor configuration, passed to the collector as-is. Covers credentials, not PII. Applies to attributes at every level and to log bodies, including nested maps and slices. Maps merge with these defaults but lists replace them, so overriding `blocked_key_patterns` must repeat the entries you want to keep. An empty config fails the render, because the processor's own default deletes every attribute. |
| redaction.enabled | bool | false | Mask credentials in the agent's logs, metrics and traces pipelines, via the redaction processor. Off by default: the rules have to match your own key and secret formats, and an over-broad one silently masks data you need. |
| resourceDetection.detectors | list | ["env"] | Detectors to run, in order. The first detector to supply an attribute wins; attributes already on the telemetry are never replaced. Use [env, eks, ec2] on EKS, [env, gcp] on GKE, [env, aks, azure] on AKS, [env] anywhere else, and keep ec2 after eks so cloud.platform stays aws_eks. A detector that fails, or an empty list, stops the collector from starting. |
| resourceDetection.enabled | bool | false | Add cloud and host attributes such as cloud.provider, cloud.region, cloud.account.id and host.id, via the resource_detection processor. Off by default because a detector that fails stops the collector from starting, so match the detectors below to where you actually run. |
| resourceDetection.timeout | string | "15s" | Deadline for the whole detection pass, and the HTTP client timeout the detectors use. Not per detector. |
| resources.limits | object | `{"cpu":"500m","memory":"512Mi"}` | Resource limits. |
| resources.limits.cpu | string | "500m" | CPU limit. |
| resources.limits.memory | string | "512Mi" | Memory limit. Also what memory_limiter is scaled from: it starts refusing data at 80% of this. With no limit set it reads the node's total memory instead, so the pod is OOMKilled before it ever sheds load. |
| resources.requests | object | `{"cpu":"100m","memory":"128Mi"}` | Resource requests. |
| resources.requests.cpu | string | "100m" | CPU request. |
| resources.requests.memory | string | "128Mi" | Memory request. |
| secret.create | bool | false | Create the Kubernetes secret holding the Tsuga credentials. Leave this false only when a secret named secret.name already exists: every collector reads TSUGA_API_KEY and TSUGA_OTLP_ENDPOINT from it, and a missing secret leaves the pods in CreateContainerConfigError. |
| secret.keyMapping | object | `{"TSUGA_API_KEY":"TSUGA_API_KEY","TSUGA_OTLP_ENDPOINT":"TSUGA_OTLP_ENDPOINT"}` | Key mapping for existing secret (used when create=false). Maps chart expected keys to keys in the existing secret. |
| secret.keyMapping.TSUGA_API_KEY | string | "TSUGA_API_KEY" | Key name in the secret for Tsuga API key. |
| secret.keyMapping.TSUGA_OTLP_ENDPOINT | string | "TSUGA_OTLP_ENDPOINT" | Key name in the secret for Tsuga OTLP endpoint. |
| secret.name | string | "otel-secret" | Name of the secret. Used when create=true (name of secret to create). Used when create=false (name of existing secret to use). |
| secret.validation | object | `{"mandatoryKeys":["TSUGA_API_KEY","TSUGA_OTLP_ENDPOINT"],"requireMandatoryKeys":true}` | Validation settings. |
| secret.validation.mandatoryKeys | list | ["TSUGA_API_KEY", "TSUGA_OTLP_ENDPOINT"] | Mandatory keys that must be present in the secret. Currently unused: the set requireMandatoryKeys checks is hardcoded in the chart's validation helper, so editing this list has no effect. |
| secret.validation.requireMandatoryKeys | bool | true | Fail the install when the Tsuga credentials the chart is about to write into the secret are empty. Only applies while secret.create is true; the chart cannot inspect an existing secret. |
| serviceAccount.annotations | object | {} | Annotations to add to the service account Useful for IRSA (IAM Roles for Service Accounts) or workload identity. |
| serviceAccount.create | bool | true | Create the service account. Set this to false to run under an account you create yourself, named by serviceAccount.name. |
| serviceAccount.name | string | "" | Name of the service account, defaulting to the release fullname. The collectors and Target Allocator run as this account and the ClusterRoleBinding targets it, whether or not the chart creates it. With create=false, an account of this name must exist before installing. |
| statefulset.affinity | object | {} | StatefulSet-specific affinity rules. If not set, inherits from global affinity configuration. |
| statefulset.config | object | `{"extraConnectors":{},"extraExporters":{},"extraProcessors":{},"extraReceivers":{},"service":{"extraExtensions":[],"pipelines":{"extraPipelines":{},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | StatefulSet collector configuration (merge-based approach). Use this to extend the default configuration. Default receivers: prometheus. Default processors: memory_limiter, batch, cumulative_to_delta, resource_detection (when resourceDetection.enabled), k8s_attributes, resource. Default extensions: health_check (when statefulset.healthCheckEndpoint is set). |
| statefulset.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration The default config defines no connectors. |
| statefulset.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration. These are merged with the default exporter (otlp_http/tsuga). |
| statefulset.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration. These are merged with default processors (memory_limiter, batch, cumulative_to_delta, k8s_attributes, resource). |
| statefulset.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration. These are merged with the default receiver (prometheus). |
| statefulset.config.service.extraExtensions | list | [] | Additional extensions to add to the service configuration. Added after the default health_check extension, which is present only when statefulset.healthCheckEndpoint is set. |
| statefulset.config.service.pipelines.extraPipelines | object | {} | Additional pipelines to add to the service configuration. These are completely new pipelines, not extensions of the default ones. |
| statefulset.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline. Added to default exporter (otlp_http/tsuga). |
| statefulset.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline. Added to default processors (memory_limiter, cumulative_to_delta, k8s_attributes, resource, batch). |
| statefulset.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline. Added to default receiver (prometheus). |
| statefulset.customConfig | object | {} | Replace default config with complete custom configuration. When set, this completely replaces the default collector configuration See cluster.customConfig for example format. |
| statefulset.extraAnnotationsMapping | list | [] | Annotations mapping configuration for the StatefulSet collector. Maps Kubernetes pod annotations to OpenTelemetry resource attributes. These are appended to default annotation mappings. Same shape as agent.extraLabelMapping. |
| statefulset.extraEnvs | list | [] | Extra environment variables for the StatefulSet collector. Added after the variables the chart injects automatically: MY_POD_IP, NODE_IP, POD_NAME, POD_UID and K8S_NODE_NAME, plus TSUGA_API_KEY and TSUGA_OTLP_ENDPOINT while any collector exports to Tsuga. |
| statefulset.extraLabelMapping | list | [] | Label mapping configuration for the StatefulSet collector. Maps Kubernetes pod labels to OpenTelemetry resource attributes. These are appended to default label mappings. Same shape as agent.extraLabelMapping. |
| statefulset.healthCheckEndpoint | string | "${env:MY_POD_IP}:13133" | Address for the health_check extension, which backs the liveness probe. Set to "" to omit the extension, and the liveness probe with it. |
| statefulset.image | string | "" | Overrides the top-level image for the StatefulSet collector only. |
| statefulset.nodeSelector | object | {} | StatefulSet-specific node selector. If not set, inherits from global nodeSelector configuration. |
| statefulset.replicas | int | 1 | Number of StatefulSet collector replicas The Target Allocator distributes targets across replicas according to targetAllocator.spec.allocationStrategy. |
| statefulset.resources | object | {} | Resource limits and requests for the StatefulSet collector. Replaces the top-level resources block wholesale rather than merging, so a partial override drops whatever it does not restate. |
| statefulset.scrapeInterval | string | "30s" | How often to scrape Prometheus targets, e.g. `60s`. Also the interval at which the collector refreshes its target list from the Target Allocator. |
| statefulset.tolerations | list | [] | StatefulSet-specific tolerations. If not set, inherits from global tolerations configuration. |
| targetAllocator.enabled | bool | false | Enable Target Allocator and paired StatefulSet collector. |
| targetAllocator.spec | object | {} | TargetAllocator CR spec (full passthrough) All fields are passed directly to the TargetAllocator CR spec. Setting spec.serviceAccount here overrides the account the chart would otherwise set. Ref: https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#targetallocator |
| targetAllocator.spec.allocationStrategy | string | "consistent-hashing" | How the Target Allocator spreads targets across collector replicas. One of `consistent-hashing`, `least-weighted`, `per-node`. per-node assigns only targets that resolve to a node, so anything else is left unscraped. |
| targetAllocator.spec.prometheusCR | object | `{"enabled":false,"podMonitorSelector":{},"serviceMonitorSelector":{}}` | PrometheusCR configuration. When enabled, the Target Allocator discovers ServiceMonitor and PodMonitor CRs. Requires monitoring.coreos.com RBAC rules (added automatically when enabled). |
| targetAllocator.spec.prometheusCR.enabled | bool | false | Enable ServiceMonitor/PodMonitor discovery. |
| targetAllocator.spec.prometheusCR.podMonitorSelector | object | {} | Selector for PodMonitor resources An empty selector ({}) matches all PodMonitors in all namespaces. |
| targetAllocator.spec.prometheusCR.serviceMonitorSelector | object | {} | Selector for ServiceMonitor resources An empty selector ({}) matches all ServiceMonitors in all namespaces. |
| tolerations | list | [] | Tolerations applied to every collector. Overridden per collector by agent.tolerations, cluster.tolerations or statefulset.tolerations. |
| tsuga.apiKey | string | "" | Tsuga API key, sent as an `Authorization: Bearer` header. Only written into the secret while secret.create is true. |
| tsuga.compression | string | "gzip" | Compression for the OTLP exporter. One of `gzip`, `zlib`, `deflate`, `snappy`, `zstd`, `lz4`, `none`. |
| tsuga.enabledForClusterReceiver | bool | true | Enable the Tsuga OTLP exporter in the cluster receiver's default config. |
| tsuga.enabledForDaemonset | bool | true | Enable the Tsuga OTLP exporter in the agent's default config. |
| tsuga.enabledForStatefulset | bool | true | Enable the Tsuga OTLP exporter in the StatefulSet collector's default config. |
| tsuga.encoding | string | "json" | Payload encoding for the OTLP exporter. One of `json`, `proto`. |
| tsuga.otlpEndpoint | string | "" | Tsuga OTLP endpoint, e.g. `https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp`. Give the base path with no signal suffix; the exporter appends `/v1/traces`, `/v1/metrics` and `/v1/logs` itself. |
| validation.enabled | bool | true | Fail the render when a generated resource name would not meet Kubernetes requirements. |
| validation.enforceNamingConventions | bool | true | Require generated names to be lowercase alphanumeric with hyphens. Only applies while validation.enabled is true. |
| validation.maxNameLength | int | 63 | Maximum length for the release fullname. The fullname is already truncated to 63 characters before this check runs, so at the default of 63 the check never fires; lower it to enforce a tighter bound. Note the operator truncates the Deployment and Service names it derives to 63 as well, which is where two releases sharing a long prefix would collide. |

## Contributing

### Development Setup

1. **Fork the repository**
2. **Clone your fork:**
   ```bash
   git clone https://github.com/tsuga-dev/helm-charts.git
   cd helm-charts/charts/opentelemetry-kube-stack
   ```
3. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes:**
   - Update templates in `templates/`
   - Update values in `values.yaml`
   - Add tests in `tests/`
   - Update documentation

### Testing

#### Unit Tests

```bash
# Run unit tests
make unittest

# Run a specific test file
helm unittest -f 'tests/secret_test.yaml' .
```

#### Integration Tests

```bash
# Run integration tests
make integration
# or
./tests/integration/test-deployment.sh
```

#### Security Tests

```bash
# Run security scan
make security
# or
./tests/security/security-scan.sh
```

#### Linting

```bash
# Lint templates
make lint
# or
helm lint .
```

#### Template Testing

```bash
# Test rendering
make template
# or
helm template test . --set clusterName="<CLUSTER_NAME>" --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" --set tsuga.apiKey="<TSUGA_API_KEY>"
```

### Documentation

To update the parameter documentation in the README:

```bash
# Generate documentation using helm-docs (run from the repo root)
helm-docs --chart-search-root=charts/opentelemetry-kube-stack
```

This will automatically update the parameter reference section in the README based on comments in `values.yaml`.

### Code Style

- Use 2 spaces for YAML indentation
- Follow Helm best practices
- Add comments for complex logic
- Use descriptive variable names
- Follow semantic versioning
- Ensure all parameters in `values.yaml` have proper helm-docs comments (`# -- Description` and `# @default -- value`)

## License

This chart is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.

## Support

For support and questions:

- Create an issue in the repository
- Review the OpenTelemetry documentation
- Join the OpenTelemetry community Slack
