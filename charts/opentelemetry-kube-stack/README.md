# opentelemetry-kube-stack

![Version: 0.11.0](https://img.shields.io/badge/Version-0.11.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1](https://img.shields.io/badge/AppVersion-v1-informational?style=flat-square)

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

- **Dual Deployment Pattern**: Implements the recommended OpenTelemetry architecture with both agent (DaemonSet) and cluster receiver (Deployment) components
- **Agent (DaemonSet)**: Collects host metrics, Kubernetes objects, and application telemetry from each node
- **Cluster Receiver (Deployment)**: Collects cluster metrics and events using the Kubernetes API server
- **Secret Management**: Configurable secrets for OpenTelemetry configuration with external secret support
- **RBAC Support**: Comprehensive service account and role-based access control
- **Resource Management**: Configurable resource limits and requests for both components
- **Host Metrics Collection**: Built-in support for node-level metrics collection
- **Kubernetes Objects Monitoring**: Automatic collection of pods, services, and other K8s resources
- **Comprehensive Observability**: Logs, metrics, and traces collection with intelligent defaults
- **Security First**: Built-in security best practices and credential management
- **Production Ready**: Optimized configurations for production environments
- **Flexible Configuration**: Merge-based or full custom configuration options

## Architecture

The chart implements the recommended OpenTelemetry architecture with two main components:

### Agent (DaemonSet)

- Runs on every node in the cluster
- Collects host metrics, Kubernetes objects, and application telemetry
- Forwards data to the cluster receiver or external backends
- Uses host networking for optimal performance (configurable)

**Default Receivers:**
- **Host Metrics** (`host_metrics`): CPU, memory, disk, filesystem, load, paging, optional network and process metrics. Pseudo filesystems (overlay, tmpfs, cgroup2, …) and container mount points are excluded to keep series counts sane.
- **Kubelet Stats** (`kubelet_stats`): Node and pod metrics via kubelet
- **OTLP**: Receives traces, metrics, and logs over gRPC (`:4317`) and HTTP (`:4318`)
- **File Logs** (`file_log`): Collects container logs from `/var/log/pods/*/*/*.log` (controlled by `agent.collectLogs`)

**Default Processors:**
- **Memory Limiter**: Prevents memory issues (80% limit, 25% spike limit). Always first, so load is shed before the pipeline spends work on data it is about to reject.
- **Resource Detection** (`resource_detection`): Cloud identity — provider, account, region, instance id (see [Cloud resource detection](#cloud-resource-detection))
- **K8s Attributes** (`k8s_attributes`): Enriches telemetry with Kubernetes metadata, container image identity, semconv-derived `service.*`, and pod/namespace/node labels (see [Telemetry enrichment](#telemetry-enrichment))
- **Resource**: Adds `k8s.node.name`, so host metrics are attributable to a node, plus `k8s.cluster.name` when `clusterName` is set
- **Cumulative To Delta**: Converts cumulative counters to delta where applicable
- **Batch**: Batches telemetry for efficient processing (`send_batch_size`/`send_batch_max_size` = 5000). Always last.

**Default Connectors:**
- **Spanmetrics**: Generates RED metrics from spans (see dimensions below)

**Default Exporters:**
- **otlp_http/tsuga**: Forwards all telemetry to the Tsuga endpoint with authentication (enabled unless `tsuga.enabledForDaemonset=false`)

**Service Pipelines:**
- **Logs**: `otlp` (+`file_log` when `agent.collectLogs`) → `memory_limiter`, `resource_detection`¹, `k8s_attributes`, `resource`, `batch` → `otlp_http/tsuga`
- **Metrics**: `otlp`, `kubelet_stats`, `span_metrics`, `host_metrics` → `memory_limiter`, `resource_detection`¹, `k8s_attributes`, `resource`, `cumulativetodelta`, `batch` → `otlp_http/tsuga`
- **Traces**: `otlp` → `memory_limiter`, `resource_detection`¹, `k8s_attributes`, `resource`, `batch` → `otlp_http/tsuga`, `span_metrics`

Collector self-telemetry is exported through `service::telemetry`, not a pipeline.

¹ Only present when `resourceDetection.enabled` is true (the default).

**Default Spanmetrics Dimensions:**
- `http.request.method`
- `http.response.status_code`
- `http.route`

`http.route` is preferred over raw URL/path attributes because it represents the logical route template and keeps metric cardinality under control. URL-like attributes such as `http.url`, `url.full`, `http.path`, and `http.target` are intentionally excluded from the default metric dimensions because they fragment metrics with IDs, query strings, and other request-specific values.

This default targets modern OpenTelemetry HTTP semantic conventions and is most useful for server spans. If your workloads still emit legacy attributes such as `http.method` and `http.status_code`, or if you want client-focused dependency metrics, override the connector dimensions through the existing merge-based config.

Example override for client-oriented HTTP dependency metrics:

```yaml
agent:
  config:
    additionalConfig:
      connectors:
        spanmetrics:
          dimensions:
            - name: http.request.method
              default: GET
            - name: http.response.status_code
            - name: server.address
```

Example override for workloads still emitting legacy HTTP semantic conventions:

```yaml
agent:
  config:
    additionalConfig:
      connectors:
        spanmetrics:
          dimensions:
            - name: http.method
              default: GET
            - name: http.status_code
            - name: http.route
```

### Cluster Receiver (Deployment)

- Collects cluster metrics and events using the Kubernetes API server
- **Pinned to a single replica.** `k8s_cluster` and `k8s_objects` do not use leader election here, so a second replica would report the same cluster state again: every cluster metric counted twice and every object ingested twice. The replica count is set in the `OpenTelemetryCollector` resource, so a manual `kubectl scale` is reconciled back to 1.

**Default Receivers:**
- **Kubernetes Cluster** (`k8s_cluster`): Collects cluster-level metrics and entity events
- **Kubernetes Objects** (`k8s_objects`): Watches pods (enabled by default, disable with `cluster.collectk8sobjects=false`)

**Default Processors:**
- **Memory Limiter**: Prevents memory issues (80% limit, 25% spike limit)
- **Resource Detection** (`resource_detection`): Cloud identity (see [Cloud resource detection](#cloud-resource-detection))
- **Resource**: Adds `k8s.cluster.name` (only when `clusterName` is set)
- **K8s Attributes** (`k8s_attributes`): Enriches telemetry with Kubernetes metadata (see [Telemetry enrichment](#telemetry-enrichment))
- **Batch**: Batches telemetry for efficient processing

**Default Exporters:**
- **otlp_http/tsuga**: Forwards to the Tsuga endpoint (enabled unless `tsuga.enabledForClusterReceiver=false`)

**Service Pipelines:**
- **Metrics**: `k8s_cluster` → `memory_limiter`, `resource_detection`¹, `resource`², `k8s_attributes`, `batch` → `otlp_http/tsuga`
- **Entity Events (Logs)**: `k8s_cluster` (+`k8s_objects` when enabled) → `memory_limiter`, `resource_detection`¹, `resource`², `k8s_attributes`, `batch` → `otlp_http/tsuga`

¹ Only present when `resourceDetection.enabled` is true (the default).
² Only present when `clusterName` is set.

### Telemetry enrichment

All three collectors share one `k8s_attributes` extract configuration, so the same pod is described identically no matter which collector saw the telemetry.

Beyond the usual workload metadata, the defaults add:

- **Container identity** — `k8s.container.name`, `container.image.name`, `container.image.tag`. This is what makes "did this start with the last deploy?" answerable, and is bounded by the number of images in the cluster.
- **Semconv-derived service identity** — `service.name`, `service.version`, `service.namespace`, computed by the processor from the well-known `app.kubernetes.io/name` label, then the workload name, with the version from the image tag. Workloads that ship telemetry without a configured service name no longer land as `unknown_service`.
- **Namespace-level ownership** — `resource.opentelemetry.io/team` and `.../env` are read from the namespace as well as the pod, because ownership is usually declared once per namespace.
- **Node topology** — `cloud.region`, `cloud.availability_zone` and `host.type` from the `topology.kubernetes.io/*` and `node.kubernetes.io/instance-type` node labels. Every managed cluster sets these, and unlike a cloud metadata detector it costs no extra call.

Precedence is **sender > pod > namespace > node**: the processor never overwrites an attribute that is already on the resource, so anything an SDK sets wins, and the explicit `resource.opentelemetry.io/*` pod labels and annotations override everything derived.

Deliberately **not** extracted, despite being available: `k8s.pod.ip`, `k8s.pod.hostname`, `container.id` and `service.instance.id`. Each either takes a new value on every pod or container restart, or simply restates `k8s.pod.name`. They would add a high-cardinality dimension to every datapoint without identifying anything `k8s.pod.name` and `k8s.pod.uid` do not already identify.

Add your own mappings with `agent.extraLabelMapping` / `agent.extraAnnotationsMapping` (and the `cluster.*` / `statefulset.*` equivalents); they are appended to the shared block.

> **Upgrade note:** a workload that previously reported no `service.name` will start reporting one derived from its Kubernetes identity. In Tsuga it moves out of `unknown_service` and into its own service, so existing dashboards or monitors that filter on `unknown_service` need updating.

### Cloud resource detection

`resourceDetection` (on by default) runs the `resource_detection` processor on every collector, adding `cloud.provider`, `cloud.platform`, `cloud.account.id`, `cloud.region` and `host.id` — the actual instance id, which is what lets you pivot from telemetry to the cloud console.

Detected values never override attributes the sender already set (`override: false`), and detection runs before `k8s_attributes`, so an explicit `clusterName` always wins over anything detected.

**On local and bare-metal clusters, turn this off:**

```bash
helm install ... --set resourceDetection.enabled=false
```

The cloud detectors probe the link-local metadata service at `169.254.169.254`. On kind, minikube, k3s, Docker Desktop or on-prem nothing answers that address: collectors still start and telemetry still flows, but each one waits out `resourceDetection.timeout` on startup and logs a detector error. On a real cloud it is also worth trimming `resourceDetection.detectors` to just your provider, which skips the other providers' probes entirely.

#### EKS cluster name detection and IAM

Every EKS attribute is served by the instance metadata service for free — except `k8s.cluster.name`, which costs an `ec2:DescribeInstances` API call. It is therefore **opt-in** via `resourceDetection.detectEksClusterName`; left on, it would log an error on every EKS cluster whose collector role lacks the permission. For most users, setting `clusterName` is simpler and costs nothing.

This permission cannot be granted by this chart. `ec2:DescribeInstances` is an **AWS IAM** permission, a different authorization system from the Kubernetes RBAC that the chart's `ClusterRole` manages — a `ClusterRole` grants access to the Kubernetes API only, never to an AWS API. Creating the IAM role itself is an AWS account-level change made outside the cluster. The chart's part is the service account annotation hook; the rest is yours.

To enable it, attach this policy to an IAM role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "ec2:DescribeInstances", "Resource": "*" }
  ]
}
```

Then bind the role to the collector's service account, either with **IRSA**:

```yaml
resourceDetection:
  detectEksClusterName: true
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>
```

or with **EKS Pod Identity**, which needs no annotation at all — create a pod identity association pointing at the release namespace and the service account name (`<release>-opentelemetry-kube-stack` unless you set `serviceAccount.name`), then set `resourceDetection.detectEksClusterName=true`.

The in-cluster RBAC the chart creates is already complete for everything the collectors do against the Kubernetes API.

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
      endpoint: http://otel-collector:4318
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
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" \
  --set tsuga.apiKey="<TSUGA_API_KEY>"
```

#### Option 2: Direct Installation

```bash
# Install directly from the chart directory
helm install my-otel-stack ./opentelemetry-kube-stack \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" \
  --set tsuga.apiKey="<TSUGA_API_KEY>"
```

#### Option 3: Using Values File

```bash
# Create a values file
cat > my-values.yaml << EOF
tsuga:
  otlpEndpoint: "https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp"
  apiKey: "<TSUGA_API_KEY>"
secret:
  create: true
EOF

# Install with values file
helm install my-otel-stack ./opentelemetry-kube-stack -f my-values.yaml
```

## Configuration

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | {} | Affinity rules for pod scheduling Used as default when agent.affinity is not set |
| agent.addLogsVolumes | bool | true | Add logs volumes to the agent When true, adds volumes for log collection Even if collectLogs is false, the volumes are added |
| agent.affinity | object | {} | Agent-specific affinity rules If not set, inherits from global affinity configuration |
| agent.collectLogs | bool | true | Collect logs from the host and containers When true, enables filelog receiver to collect logs from /var/log/pods Also mounts required volumes for log collection |
| agent.collectNetwork | bool | false | Collect host network metrics When true, enables network scraper in hostmetrics receiver |
| agent.collectOtelLogs | bool | false | Collect OpenTelemetry collector logs When false (default), excludes the collector's own container logs to avoid a self-ingestion feedback loop that produces container-parser errors |
| agent.collectProcesses | bool | false | Collect host processes metrics When true, enables processes and process scrapers in hostmetrics receiver |
| agent.config | object | `{"extraConnectors":{},"extraExporters":{},"extraExtensions":{},"extraProcessors":{},"extraReceivers":{},"extraTelemetry":{},"service":{"extraExtensions":[],"pipelines":{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | Agent collector configuration (merge-based approach) Use this to extend the default configuration Default config includes: filelog, kubelet_stats, host_metrics, otlp, prometheus/self receivers Default processors: k8s_attributes, memory_limiter, batch, cumulativetodelta, resource |
| agent.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration These are merged with default connectors |
| agent.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration These are merged with default exporters (otlp_http/tsuga) |
| agent.config.extraExtensions | object | {} | Additional extensions to merge into the collector configuration These are merged with default extensions (health_check) |
| agent.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration These are merged with default processors |
| agent.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration These are merged with default receivers |
| agent.config.extraTelemetry | object | {} | Additional telemetry to merge into the collector configuration Merges with default telemetry (Prometheus metrics on port 8888) |
| agent.config.service | object | `{"extraExtensions":[],"pipelines":{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}` | Service configuration |
| agent.config.service.extraExtensions | list | [] | Additional extensions to add to the service configuration Added to default extensions (health_check) |
| agent.config.service.pipelines | object | `{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}` | Pipeline configuration |
| agent.config.service.pipelines.logs | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Logs pipeline configuration |
| agent.config.service.pipelines.logs.extraExporters | list | [] | Additional exporters to add to the logs pipeline Added to default exporter (otlp_http/tsuga) |
| agent.config.service.pipelines.logs.extraProcessors | list | [] | Additional processors to add to the logs pipeline Added to default processors (k8s_attributes, memory_limiter, batch, resource) |
| agent.config.service.pipelines.logs.extraReceivers | list | [] | Additional receivers to add to the logs pipeline Added to default receivers (otlp, filelog) |
| agent.config.service.pipelines.metrics | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Metrics pipeline configuration |
| agent.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline Added to default exporter (otlp_http/tsuga) |
| agent.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline Added to default processors (k8s_attributes, memory_limiter, batch, cumulativetodelta, resource) |
| agent.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline Added to default receivers (otlp, kubelet_stats, spanmetrics, host_metrics) |
| agent.config.service.pipelines.traces | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Traces pipeline configuration |
| agent.config.service.pipelines.traces.extraExporters | list | [] | Additional exporters to add to the traces pipeline Added to default exporters (otlp_http/tsuga, spanmetrics) |
| agent.config.service.pipelines.traces.extraProcessors | list | [] | Additional processors to add to the traces pipeline Added to default processors (k8s_attributes, memory_limiter, batch, resource) |
| agent.config.service.pipelines.traces.extraReceivers | list | [] | Additional receivers to add to the traces pipeline Added to default receivers (otlp) |
| agent.customConfig | object | {} | Replace default config with complete custom configuration When set, this completely replaces the default collector configuration Use this for full control over the OpenTelemetry Collector config See cluster.customConfig for example format |
| agent.enabled | bool | true | Enable agent daemonset deployment |
| agent.extraAnnotationsMapping | list | [] | Annotations mapping configuration for agent Maps Kubernetes pod annotations to OpenTelemetry resource attributes These are appended to default annotation mappings Format: List of objects with tag_name, key, and from fields |
| agent.extraEnvs | list | [] | Extra environment variables for agent These are in addition to automatic secret env vars (TSUGA_API_KEY, TSUGA_OTLP_ENDPOINT, MY_POD_IP) |
| agent.extraLabelMapping | list | [] | Label mapping configuration for agent Maps Kubernetes pod labels to OpenTelemetry resource attributes These are appended to default label mappings Format: List of objects with tag_name, key, and from fields Example:   extraLabelMapping:     - tag_name: "app.version"       key: "app.version"       from: "pod" |
| agent.hostNetwork | bool | true | Enable host network for agent (recommended for optimal performance) When true, agent uses host networking for better performance |
| agent.image | string | "" | OpenTelemetry Collector image for agent Defaults to: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s |
| agent.nodeSelector | object | {} | Agent-specific node selector If not set, inherits from global nodeSelector configuration |
| agent.resources | object | {} | Agent-specific resource limits and requests If not set, inherits from global resources configuration |
| agent.tolerations | list | [] | Agent-specific tolerations If not set, inherits from global tolerations configuration |
| autoInstrumentation.annotations | object | {} | Extra annotations to add to the Instrumentation resource |
| autoInstrumentation.apiVersion | string | "opentelemetry.io/v1alpha1" | apiVersion for the Instrumentation CR (depends on operator version) Common values: "opentelemetry.io/v1alpha1" |
| autoInstrumentation.enabled | bool | false | Enable OpenTelemetry Operator auto-instrumentation (Instrumentation CR) Requires the OpenTelemetry Operator to be installed in the cluster. |
| autoInstrumentation.labels | object | {} | Extra labels to add to the Instrumentation resource |
| autoInstrumentation.nameOverride | string | "" | Override the name of the Instrumentation resource If empty, defaults to "<release-fullname>-instrumentation" |
| autoInstrumentation.spec | object | {} | Instrumentation spec (full passthrough) This is passed directly to the Instrumentation Custom Resource spec. It can include (non-exhaustive): exporter, propagators, sampler, env, resource, and language blocks like java, nodejs, python, dotnet, go, apacheHttpd. Ref: https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#instrumentation |
| cluster.affinity | object | {} | Cluster-specific affinity rules If not set, inherits from global affinity configuration |
| cluster.collectk8sobjects | bool | `true` |  |
| cluster.config | object | `{"extraConnectors":{},"extraExporters":{},"extraProcessors":{},"extraReceivers":{},"extraTelemetry":{},"service":{"extraExtensions":[],"pipelines":{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | Gateway collector configuration (merge-based approach) Use this to extend the default configuration Default config includes: k8s_cluster receiver, k8s_attributes processor, resource processor |
| cluster.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration These are merged with default connectors |
| cluster.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration These are merged with default exporters (otlp_http/tsuga) |
| cluster.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration These are merged with default processors (k8s_attributes, resource) |
| cluster.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration These are merged with default receivers (k8s_cluster) Example:   extraReceivers:     prometheus:       config:         scrape_configs:           - job_name: 'my-service' |
| cluster.config.extraTelemetry | object | {} | Additional telemetry to merge into the collector configuration Merges with default telemetry |
| cluster.config.service | object | `{"extraExtensions":[],"pipelines":{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}` | Service configuration |
| cluster.config.service.extraExtensions | list | [] | Additional extensions to add to the service configuration Added to default extensions |
| cluster.config.service.pipelines | object | `{"extraPipelines":{},"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}` | Pipeline configuration |
| cluster.config.service.pipelines.extraPipelines | object | {} | Additional pipelines to add to the service configuration These are completely new pipelines (not extending default ones) Example:   extraPipelines:     custom-logs:       receivers: [custom-receiver]       processors: [batch]       exporters: [custom-exporter] |
| cluster.config.service.pipelines.logs | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Logs pipeline configuration |
| cluster.config.service.pipelines.logs.extraExporters | list | [] | Additional exporters to add to the logs pipeline Added to default exporter (otlp_http/tsuga) |
| cluster.config.service.pipelines.logs.extraProcessors | list | [] | Additional processors to add to the logs pipeline Added to default processors (resource) |
| cluster.config.service.pipelines.logs.extraReceivers | list | [] | Additional receivers to add to the logs pipeline Added to default receiver (k8s_cluster) |
| cluster.config.service.pipelines.metrics | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Metrics pipeline configuration |
| cluster.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline Added to default exporter (otlp_http/tsuga) |
| cluster.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline Added to default processors (resource) |
| cluster.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline Added to default receiver (k8s_cluster) |
| cluster.config.service.pipelines.traces | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Traces pipeline configuration |
| cluster.config.service.pipelines.traces.extraExporters | list | [] | Additional exporters to add to the traces pipeline Added to default exporter (otlp_http/tsuga) |
| cluster.config.service.pipelines.traces.extraProcessors | list | [] | Additional processors to add to the traces pipeline Added to default processors (resource) |
| cluster.config.service.pipelines.traces.extraReceivers | list | [] | Additional receivers to add to the traces pipeline Added to default receiver (k8s_cluster) |
| cluster.customConfig | object | {} | Replace default config with complete custom configuration When set, this completely replaces the default collector configuration Use this for full control over the OpenTelemetry Collector config Example:   customConfig: |-     receivers:       k8s_cluster:         collection_interval: 30s     processors:       batch: {}     exporters:       otlp_http/tsuga:         endpoint: ${TSUGA_OTLP_ENDPOINT}     service:       pipelines:         metrics:           receivers: [k8s_cluster]           processors: [batch]           exporters: [otlp_http/tsuga] |
| cluster.enabled | bool | true | Enable cluster receiver (gateway) deployment |
| cluster.extraAnnotationsMapping | list | [] | Annotations mapping configuration for cluster receiver Maps Kubernetes pod annotations to OpenTelemetry resource attributes These are appended to default annotation mappings Format: List of objects with tag_name, key, and from fields |
| cluster.extraEnvs | list | [] | Extra environment variables for cluster receiver These are in addition to automatic secret env vars (TSUGA_API_KEY, TSUGA_OTLP_ENDPOINT, MY_POD_IP) Example:   extraEnvs:     - name: CUSTOM_VAR       value: "custom-value" |
| cluster.extraLabelMapping | list | [] | Label mapping configuration for cluster receiver Maps Kubernetes pod labels to OpenTelemetry resource attributes These are appended to default label mappings Format: List of objects with tag_name, key, and from fields Example:   extraLabelMapping:     - tag_name: "app.version"       key: "app.version"       from: "pod" |
| cluster.image | string | "" | OpenTelemetry Collector image for cluster receiver Defaults to: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s |
| cluster.nodeSelector | object | {} | Cluster-specific node selector If not set, inherits from global nodeSelector configuration |
| cluster.resources | object | {} | Cluster-specific resource limits and requests If not set, inherits from global resources configuration |
| cluster.tolerations | list | [] | Cluster-specific tolerations If not set, inherits from global tolerations configuration |
| clusterName | string | "" | The name of the cluster to be used in the resource attributes This value is added to all telemetry data as k8s.cluster.name RECOMMENDED: Set this value to identify your cluster in telemetry data If not set, the k8s.cluster.name attribute will be omitted from telemetry |
| fullnameOverride | string | "" | Override the full name used in resource naming |
| image | string | "" | Default OpenTelemetry Collector image Used as fallback when cluster.image or agent.image are not set Format: registry/repository:tag |
| nameOverride | string | "" | Override the chart name used in resource naming |
| nodeSelector | object | {} | Node selector for daemonset mode (agent) Used as default when agent.nodeSelector is not set |
| opentelemetry-operator.admissionWebhooks.failurePolicy | string | `"Ignore"` |  |
| opentelemetry-operator.crds.create | bool | `false` |  |
| opentelemetry-operator.enabled | bool | `false` |  |
| opentelemetry-operator.manager.collectorImage.repository | string | `"otel/opentelemetry-collector-k8s"` |  |
| rbac | object | `{"create":true}` | RBAC configuration |
| rbac.create | bool | true | Create RBAC resources (ClusterRole and ClusterRoleBinding) Required for collecting Kubernetes cluster metrics and metadata |
| resourceDetection.detectEksClusterName | bool | false | Let the EKS detector resolve k8s.cluster.name (AWS only)  Every other EKS attribute comes from the instance metadata service for free. This one does not: it costs an ec2:DescribeInstances API call, so leaving it on would log an error on every EKS cluster whose collector role lacks that permission. Most users should simply set `clusterName` instead.  This is an AWS IAM permission, not Kubernetes RBAC, so the chart cannot grant it. Attach a role with the policy below via IRSA or EKS Pod Identity, then point the service account at it:    {"Version": "2012-10-17", "Statement": [{     "Effect": "Allow", "Action": "ec2:DescribeInstances", "Resource": "*"}]}    serviceAccount:     annotations:       eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/<ROLE>  |
| resourceDetection.detectors | list | ["env", "eks", "aks", "gcp", "ec2", "azure"] | Detectors to run, in order. Earlier detectors win on conflict. `env` reads OTEL_RESOURCE_ATTRIBUTES and costs nothing on any cluster. Detected values never override attributes the sender already set. |
| resourceDetection.enabled | bool | true | Run the resource_detection processor on all collectors |
| resourceDetection.timeout | string | "2s" | How long each detector may take before it gives up. |
| resources.limits | object | `{"cpu":"500m","memory":"512Mi"}` | Resource limits |
| resources.limits.cpu | string | "500m" | CPU limit |
| resources.limits.memory | string | "512Mi" | Memory limit |
| resources.requests | object | `{"cpu":"100m","memory":"128Mi"}` | Resource requests |
| resources.requests.cpu | string | "100m" | CPU request |
| resources.requests.memory | string | "128Mi" | Memory request |
| secret.create | bool | false | Create a Kubernetes secret for OpenTelemetry configuration If true: creates a secret with values from tsuga configuration If false: uses an existing secret (must be created separately) |
| secret.keyMapping | object | `{"TSUGA_API_KEY":"TSUGA_API_KEY","TSUGA_OTLP_ENDPOINT":"TSUGA_OTLP_ENDPOINT"}` | Key mapping for existing secret (used when create=false) Maps chart expected keys to keys in the existing secret Example: If your secret uses "<API_KEY_SECRET_KEY>" instead of "TSUGA_API_KEY", set:   keyMapping:     TSUGA_API_KEY: "<API_KEY_SECRET_KEY>" |
| secret.keyMapping.TSUGA_API_KEY | string | "TSUGA_API_KEY" | Key name in the secret for Tsuga API key |
| secret.keyMapping.TSUGA_OTLP_ENDPOINT | string | "TSUGA_OTLP_ENDPOINT" | Key name in the secret for Tsuga OTLP endpoint |
| secret.name | string | "otel-secret" | Name of the secret Used when create=true (name of secret to create) Used when create=false (name of existing secret to use) |
| secret.validation | object | `{"mandatoryKeys":["TSUGA_API_KEY","TSUGA_OTLP_ENDPOINT"],"requireMandatoryKeys":true}` | Validation settings |
| secret.validation.mandatoryKeys | list | ["TSUGA_API_KEY", "TSUGA_OTLP_ENDPOINT"] | Mandatory keys that must be present in the secret |
| secret.validation.requireMandatoryKeys | bool | true | Require all mandatory keys to be present in the secret When true, chart will fail if required keys are missing |
| serviceAccount | object | `{"annotations":{},"create":true,"name":""}` | Service account configuration |
| serviceAccount.annotations | object | {} | Annotations to add to the service account Useful for IRSA (IAM Roles for Service Accounts) or workload identity |
| serviceAccount.create | bool | true | Create a service account for the OpenTelemetry collectors |
| serviceAccount.name | string | "" | Name of the service account If not set, will be auto-generated based on release name |
| statefulset.affinity | object | {} | StatefulSet-specific affinity rules |
| statefulset.config | object | `{"extraConnectors":{},"extraExporters":{},"extraProcessors":{},"extraReceivers":{},"extraTelemetry":{},"service":{"extraExtensions":[],"pipelines":{"extraPipelines":{},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | StatefulSet collector configuration (merge-based approach) |
| statefulset.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration |
| statefulset.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration |
| statefulset.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration |
| statefulset.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration |
| statefulset.config.extraTelemetry | object | {} | Additional telemetry to merge into the collector configuration |
| statefulset.config.service | object | `{"extraExtensions":[],"pipelines":{"extraPipelines":{},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}` | Service configuration |
| statefulset.config.service.extraExtensions | list | [] | Additional extensions to add to the service configuration |
| statefulset.config.service.pipelines | object | `{"extraPipelines":{},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}` | Pipeline configuration |
| statefulset.config.service.pipelines.extraPipelines | object | {} | Additional pipelines to add to the service configuration |
| statefulset.config.service.pipelines.metrics | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Metrics pipeline configuration |
| statefulset.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline Added to default exporter (otlp_http/tsuga) |
| statefulset.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline Added to default processors (k8s_attributes, batch) |
| statefulset.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline Added to default receiver (prometheus) |
| statefulset.customConfig | object | {} | Replace default config with complete custom configuration |
| statefulset.extraAnnotationsMapping | list | [] | Annotations mapping configuration for agent Maps Kubernetes pod annotations to OpenTelemetry resource attributes These are appended to default annotation mappings Format: List of objects with tag_name, key, and from fields |
| statefulset.extraEnvs | list | [] | Extra environment variables for statefulset collector |
| statefulset.extraLabelMapping | list | [] | Label mapping configuration for agent Maps Kubernetes pod labels to OpenTelemetry resource attributes These are appended to default label mappings Format: List of objects with tag_name, key, and from fields Example:   extraLabelMapping:     - tag_name: "app.version"       key: "app.version"       from: "pod" |
| statefulset.image | string | "" | OpenTelemetry Collector image for statefulset collector |
| statefulset.nodeSelector | object | {} | StatefulSet-specific node selector |
| statefulset.replicas | int | 1 | Number of StatefulSet collector replicas The Target Allocator distributes targets evenly across replicas. |
| statefulset.resources | object | {} | StatefulSet-specific resource limits and requests |
| statefulset.tolerations | list | [] | StatefulSet-specific tolerations |
| targetAllocator.enabled | bool | false | Enable Target Allocator and paired StatefulSet collector |
| targetAllocator.spec | object | {} | TargetAllocator CR spec (full passthrough) All fields are passed directly to the TargetAllocator CR spec. Ref: https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#targetallocator |
| targetAllocator.spec.allocationStrategy | string | "consistent-hashing" | Allocation strategy for distributing targets across collector replicas Options: consistent-hashing (default), least-weighted, per-node |
| targetAllocator.spec.prometheusCR | object | `{"enabled":false,"podMonitorSelector":{},"serviceMonitorSelector":{}}` | PrometheusCR configuration When enabled, the Target Allocator discovers ServiceMonitor and PodMonitor CRs. Requires monitoring.coreos.com RBAC rules (added automatically when enabled). |
| targetAllocator.spec.prometheusCR.enabled | bool | false | Enable ServiceMonitor/PodMonitor discovery |
| targetAllocator.spec.prometheusCR.podMonitorSelector | object | {} | Selector for PodMonitor resources An empty selector ({}) matches all PodMonitors in all namespaces. |
| targetAllocator.spec.prometheusCR.serviceMonitorSelector | object | {} | Selector for ServiceMonitor resources An empty selector ({}) matches all ServiceMonitors in all namespaces. |
| tolerations | list | [] | Tolerations for daemonset mode (agent) Used as default when agent.tolerations is not set |
| tsuga.apiKey | string | "" | Tsuga API key for authentication Set via: --set tsuga.apiKey="<TSUGA_API_KEY>" Or use external secrets: --set tsuga.apiKey="" |
| tsuga.enabledForClusterReceiver | bool | true | Enable Tsuga OTLP exporter for the cluster receiver (gateway) |
| tsuga.enabledForDaemonset | bool | true | Enable Tsuga OTLP exporter for the agent DaemonSet |
| tsuga.enabledForStatefulset | bool | true | Enable Tsuga OTLP exporter for the StatefulSet collector (when targetAllocator is enabled) |
| tsuga.otlpEndpoint | string | "" | Tsuga OTLP endpoint for telemetry data Set via: --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" |
| validation | object | `{"enabled":true,"enforceNamingConventions":true,"maxNameLength":63}` | Resource naming validation |
| validation.enabled | bool | true | Enable resource name validation When enabled, validates resource names meet Kubernetes requirements |
| validation.enforceNamingConventions | bool | true | Validate naming conventions Enforces Kubernetes naming conventions (lowercase alphanumeric and hyphens) |
| validation.maxNameLength | int | 63 | Maximum length for resource names (Kubernetes limit is 63 characters) |

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
helm template test . --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" --set tsuga.apiKey="<TSUGA_API_KEY>"
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
- Check the troubleshooting section above
- Review the OpenTelemetry documentation
- Join the OpenTelemetry community Slack
