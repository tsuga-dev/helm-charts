# opentelemetry-kube-stack

![Version: 0.2.6](https://img.shields.io/badge/Version-0.2.6-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1](https://img.shields.io/badge/AppVersion-v1-informational?style=flat-square)

A comprehensive Helm chart for OpenTelemetry Kubernetes operator with Tsuga integration, featuring dual deployment pattern (agent DaemonSet + cluster receiver), secure credential management, and production-ready configurations for telemetry collection to Tsuga platform.

**Homepage:** <https://tsuga-dev.github.io/helm-charts/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| OpenTelemetry Team | <antonin@tsuga.com> |  |

## Source Code

* <https://github.com/tsuga-dev/helm-charts>

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
- **Host Metrics**: CPU, memory, disk, filesystem, load, optional network and process metrics
- **Kubelet Stats**: Node and pod metrics via kubelet
- **Prometheus**: Scrapes application metrics from pods with `prometheus.io/scrape: true` annotation
- **OTLP**: Receives traces, metrics, and logs
- **Jaeger** and **Zipkin**: Receive traces via Jaeger and Zipkin protocols
- **File Logs**: Collects container logs from `/var/log/pods/*/*/*.log` (controlled by `agent.collectLogs`)

**Default Processors:**
- **K8s Attributes**: Enriches telemetry with Kubernetes metadata and selected pod labels
- **Memory Limiter**: Prevents memory issues (80% limit, 25% spike limit)
- **Batch**: Batches telemetry for efficient processing
- **Cumulative To Delta**: Converts cumulative counters to delta where applicable
- **Resource**: Adds attributes including `k8s.cluster.name` (from `clusterName`)

**Default Exporters:**
- **OTLP/Tsuga**: Forwards all telemetry to Tsuga endpoint with authentication

**Service Pipelines:**
- **Logs**: `otlp`, `filelog` → `k8sattributes`, `memory_limiter`, `batch`, `resource` → `otlphttp/tsuga`
- **Metrics**: `otlp`, `prometheus`, `kubeletstats`, `spanmetrics`, `hostmetrics` → `k8sattributes`, `memory_limiter`, `batch`, `cumulativetodelta`, `resource` → `otlphttp/tsuga`
- **Traces**: `otlp`, `jaeger`, `zipkin` → `k8sattributes`, `memory_limiter`, `batch`, `resource` → `otlphttp/tsuga`, `spanmetrics`

### Cluster Receiver (Deployment)

- Collects cluster metrics and events using the Kubernetes API server

**Default Receivers:**
- **Kubernetes Cluster**: Collects cluster-level metrics and entity events via `k8s_cluster`

**Default Processors:**
- **Resource**: Adds deployment/cluster attributes (defaults include `k8s.cluster.name`)
- **K8s Attributes**: Optional Kubernetes metadata extraction

**Default Exporters:**
- **OTLP**: Forwards to Tsuga endpoint

**Service Pipelines:**
- **Metrics**: `k8s_cluster` → `resource` → `otlphttp/tsuga`
- **Entity Events (Logs)**: `k8s_cluster` → `resource` → `otlphttp/tsuga`

## Quick Start

Use the deploy script

```bash
./deploy.sh
```

## Installation

### Install the OpenTelemetry Operator

First, install the OpenTelemetry Operator in your cluster:

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

### Install the Chart

#### Option 1: Using Chart Repository (Recommended)

```bash
# Add the repository
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
helm repo update

# Install with Tsuga configuration
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://your-tsuga-endpoint.com" \
  --set tsuga.apiKey="your-api-key-here"
```

#### Option 2: Direct Installation

```bash
# Install directly from the chart directory
helm install my-otel-stack ./opentelemetry-kube-stack \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://your-tsuga-endpoint.com" \
  --set tsuga.apiKey="your-api-key-here"
```

#### Option 3: Using Values File

```bash
# Create a values file
cat > my-values.yaml << EOF
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com"
  apiKey: "your-api-key-here"
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
| agent.affinity | object | {} | Agent-specific affinity rules If not set, inherits from global affinity configuration |
| agent.collectLogs | bool | true | Collect logs from the host and containers When true, enables filelog receiver to collect logs from /var/log/pods Also mounts required volumes for log collection |
| agent.collectNetwork | bool | false | Collect host network metrics When true, enables network scraper in hostmetrics receiver |
| agent.collectOtelLogs | bool | true | Collect OpenTelemetry collector logs When false, excludes OpenTelemetry collector logs from collection Useful to avoid log loops |
| agent.collectProcesses | bool | false | Collect host processes metrics When true, enables processes and process scrapers in hostmetrics receiver |
| agent.config | object | `{"extraConnectors":{},"extraExporters":{},"extraExtensions":{},"extraProcessors":{},"extraReceivers":{},"extraTelemetry":{},"service":{"extraExtensions":{},"pipelines":{"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | Agent collector configuration (merge-based approach) Use this to extend the default configuration Default config includes: filelog, jaeger, kubeletstats, hostmetrics, otlp, prometheus, zipkin receivers Default processors: k8sattributes, memory_limiter, batch, cumulativetodelta, resource |
| agent.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration These are merged with default connectors |
| agent.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration These are merged with default exporters (otlphttp/tsuga) |
| agent.config.extraExtensions | object | {} | Additional extensions to merge into the collector configuration These are merged with default extensions (health_check) |
| agent.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration These are merged with default processors |
| agent.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration These are merged with default receivers |
| agent.config.extraTelemetry | object | {} | Additional telemetry to merge into the collector configuration Merges with default telemetry (Prometheus metrics on port 8888) |
| agent.config.service | object | `{"extraExtensions":{},"pipelines":{"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}` | Service configuration |
| agent.config.service.extraExtensions | object | {} | Additional extensions to add to the service configuration Added to default extensions (health_check) |
| agent.config.service.pipelines | object | `{"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}` | Pipeline configuration |
| agent.config.service.pipelines.logs | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Logs pipeline configuration |
| agent.config.service.pipelines.logs.extraExporters | list | [] | Additional exporters to add to the logs pipeline Added to default exporter (otlphttp/tsuga) |
| agent.config.service.pipelines.logs.extraProcessors | list | [] | Additional processors to add to the logs pipeline Added to default processors (k8sattributes, memory_limiter, batch, resource) |
| agent.config.service.pipelines.logs.extraReceivers | list | [] | Additional receivers to add to the logs pipeline Added to default receivers (otlp, filelog) |
| agent.config.service.pipelines.metrics | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Metrics pipeline configuration |
| agent.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline Added to default exporter (otlphttp/tsuga) |
| agent.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline Added to default processors (k8sattributes, memory_limiter, batch, cumulativetodelta, resource) |
| agent.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline Added to default receivers (otlp, prometheus, kubeletstats, spanmetrics, hostmetrics) |
| agent.config.service.pipelines.traces | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Traces pipeline configuration |
| agent.config.service.pipelines.traces.extraExporters | list | [] | Additional exporters to add to the traces pipeline Added to default exporters (otlphttp/tsuga, spanmetrics) |
| agent.config.service.pipelines.traces.extraProcessors | list | [] | Additional processors to add to the traces pipeline Added to default processors (k8sattributes, memory_limiter, batch, resource) |
| agent.config.service.pipelines.traces.extraReceivers | list | [] | Additional receivers to add to the traces pipeline Added to default receivers (otlp, jaeger, zipkin) |
| agent.customConfig | object | {} | Replace default config with complete custom configuration When set, this completely replaces the default collector configuration Use this for full control over the OpenTelemetry Collector config See cluster.customConfig for example format |
| agent.enabled | bool | true | Enable agent daemonset deployment |
| agent.extraAnnotationsMapping | list | [] | Annotations mapping configuration for agent Maps Kubernetes pod annotations to OpenTelemetry resource attributes These are appended to default annotation mappings Format: List of objects with tag_name, key, and from fields |
| agent.extraEnvs | list | [] | Extra environment variables for agent These are in addition to automatic secret env vars (TSUGA_API_KEY, TSUGA_OTLP_ENDPOINT, MY_POD_IP) |
| agent.extraLabelMapping | list | [] | Label mapping configuration for agent Maps Kubernetes pod labels to OpenTelemetry resource attributes These are appended to default label mappings Format: List of objects with tag_name, key, and from fields Example:   extraLabelMapping:     - tag_name: "app.version"       key: "app.version"       from: "pod" |
| agent.hostNetwork | bool | true | Enable host network for agent (recommended for optimal performance) When true, agent uses host networking for better performance |
| agent.image | string | "" | OpenTelemetry Collector image for agent Defaults to: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s |
| agent.nodeSelector | object | {} | Agent-specific node selector If not set, inherits from global nodeSelector configuration |
| agent.resources | object | {} | Agent-specific resource limits and requests If not set, inherits from global resources configuration |
| agent.tolerations | object | {} | Agent-specific tolerations If not set, inherits from global tolerations configuration |
| cluster.affinity | object | {} | Cluster-specific affinity rules If not set, inherits from global affinity configuration |
| cluster.config | object | `{"extraConnectors":{},"extraExporters":{},"extraProcessors":{},"extraReceivers":{},"extraTelemetry":{},"service":{"extraExtensions":{},"pipelines":{"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}}` | Gateway collector configuration (merge-based approach) Use this to extend the default configuration Default config includes: k8s_cluster receiver, k8sattributes processor, resource processor |
| cluster.config.extraConnectors | object | {} | Additional connectors to merge into the collector configuration These are merged with default connectors |
| cluster.config.extraExporters | object | {} | Additional exporters to merge into the collector configuration These are merged with default exporters (otlphttp/tsuga) |
| cluster.config.extraProcessors | object | {} | Additional processors to merge into the collector configuration These are merged with default processors (k8sattributes, resource) |
| cluster.config.extraReceivers | object | {} | Additional receivers to merge into the collector configuration These are merged with default receivers (k8s_cluster) Example:   extraReceivers:     prometheus:       config:         scrape_configs:           - job_name: 'my-service' |
| cluster.config.extraTelemetry | object | {} | Additional telemetry to merge into the collector configuration Merges with default telemetry |
| cluster.config.service | object | `{"extraExtensions":{},"pipelines":{"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}}` | Service configuration |
| cluster.config.service.extraExtensions | object | {} | Additional extensions to add to the service configuration Added to default extensions |
| cluster.config.service.pipelines | object | `{"logs":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"metrics":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]},"traces":{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}}` | Pipeline configuration |
| cluster.config.service.pipelines.logs | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Logs pipeline configuration |
| cluster.config.service.pipelines.logs.extraExporters | list | [] | Additional exporters to add to the logs pipeline Added to default exporter (otlphttp/tsuga) |
| cluster.config.service.pipelines.logs.extraProcessors | list | [] | Additional processors to add to the logs pipeline Added to default processors (resource) |
| cluster.config.service.pipelines.logs.extraReceivers | list | [] | Additional receivers to add to the logs pipeline Added to default receiver (k8s_cluster) |
| cluster.config.service.pipelines.metrics | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Metrics pipeline configuration |
| cluster.config.service.pipelines.metrics.extraExporters | list | [] | Additional exporters to add to the metrics pipeline Added to default exporter (otlphttp/tsuga) |
| cluster.config.service.pipelines.metrics.extraProcessors | list | [] | Additional processors to add to the metrics pipeline Added to default processors (resource) |
| cluster.config.service.pipelines.metrics.extraReceivers | list | [] | Additional receivers to add to the metrics pipeline Added to default receiver (k8s_cluster) |
| cluster.config.service.pipelines.traces | object | `{"extraExporters":[],"extraProcessors":[],"extraReceivers":[]}` | Traces pipeline configuration |
| cluster.config.service.pipelines.traces.extraExporters | list | [] | Additional exporters to add to the traces pipeline Added to default exporter (otlphttp/tsuga) |
| cluster.config.service.pipelines.traces.extraProcessors | list | [] | Additional processors to add to the traces pipeline Added to default processors (resource) |
| cluster.config.service.pipelines.traces.extraReceivers | list | [] | Additional receivers to add to the traces pipeline Added to default receiver (k8s_cluster) |
| cluster.customConfig | object | {} | Replace default config with complete custom configuration When set, this completely replaces the default collector configuration Use this for full control over the OpenTelemetry Collector config Example:   customConfig: |-     receivers:       k8s_cluster:         collection_interval: 30s     processors:       batch: {}     exporters:       otlphttp/tsuga:         endpoint: ${TSUGA_OTLP_ENDPOINT}     service:       pipelines:         metrics:           receivers: [k8s_cluster]           processors: [batch]           exporters: [otlphttp/tsuga] |
| cluster.enabled | bool | true | Enable cluster receiver (gateway) deployment |
| cluster.extraAnnotationsMapping | list | [] | Annotations mapping configuration for cluster receiver Maps Kubernetes pod annotations to OpenTelemetry resource attributes These are appended to default annotation mappings Format: List of objects with tag_name, key, and from fields |
| cluster.extraEnvs | list | [] | Extra environment variables for cluster receiver These are in addition to automatic secret env vars (TSUGA_API_KEY, TSUGA_OTLP_ENDPOINT, MY_POD_IP) Example:   extraEnvs:     - name: CUSTOM_VAR       value: "custom-value" |
| cluster.extraLabelMapping | list | [] | Label mapping configuration for cluster receiver Maps Kubernetes pod labels to OpenTelemetry resource attributes These are appended to default label mappings Format: List of objects with tag_name, key, and from fields Example:   extraLabelMapping:     - tag_name: "app.version"       key: "app.version"       from: "pod" |
| cluster.image | string | "" | OpenTelemetry Collector image for cluster receiver Defaults to: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s |
| cluster.nodeSelector | object | {} | Cluster-specific node selector If not set, inherits from global nodeSelector configuration |
| cluster.resources | object | {} | Cluster-specific resource limits and requests If not set, inherits from global resources configuration |
| cluster.tolerations | object | {} | Cluster-specific tolerations If not set, inherits from global tolerations configuration |
| clusterName | string | "" | The name of the cluster to be used in the resource attributes This value is added to all telemetry data as k8s.cluster.name |
| fullnameOverride | string | "" | Override the full name used in resource naming |
| image | string | "" | Default OpenTelemetry Collector image Used as fallback when cluster.image or agent.image are not set Format: registry/repository:tag |
| nameOverride | string | "" | Override the chart name used in resource naming |
| nodeSelector | object | {} | Node selector for daemonset mode (agent) Used as default when agent.nodeSelector is not set |
| rbac | object | `{"create":true}` | RBAC configuration |
| rbac.create | bool | true | Create RBAC resources (ClusterRole and ClusterRoleBinding) Required for collecting Kubernetes cluster metrics and metadata |
| resources.limits | object | `{"cpu":"500m","memory":"512Mi"}` | Resource limits |
| resources.limits.cpu | string | "500m" | CPU limit |
| resources.limits.memory | string | "512Mi" | Memory limit |
| resources.requests | object | `{"cpu":"100m","memory":"128Mi"}` | Resource requests |
| resources.requests.cpu | string | "100m" | CPU request |
| resources.requests.memory | string | "128Mi" | Memory request |
| secret.create | bool | false | Create a Kubernetes secret for OpenTelemetry configuration If true: creates a secret with values from tsuga configuration If false: uses an existing secret (must be created separately) |
| secret.keyMapping | object | `{"TSUGA_API_KEY":"TSUGA_API_KEY","TSUGA_OTLP_ENDPOINT":"TSUGA_OTLP_ENDPOINT"}` | Key mapping for existing secret (used when create=false) Maps chart expected keys to keys in the existing secret Example: If your secret uses "api-key" instead of "TSUGA_API_KEY", set:   keyMapping:     TSUGA_API_KEY: "api-key" |
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
| tolerations | list | [] | Tolerations for daemonset mode (agent) Used as default when agent.tolerations is not set |
| tsuga.apiKey | string | "" | Tsuga API key for authentication Set via: --set tsuga.apiKey="your-api-key-here" Or use external secrets: --set tsuga.apiKey="" |
| tsuga.otlpEndpoint | string | "" | Tsuga OTLP endpoint for telemetry data Set via: --set tsuga.otlpEndpoint="https://your-tsuga-endpoint.com" |
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

# Run specific test
helm test my-otel-stack
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
helm template test . --set tsuga.otlpEndpoint="test" --set tsuga.apiKey="test"
```

### Documentation

To update the parameter documentation in the README:

```bash
# Generate documentation using helm-docs
make docs
# or
helm-docs
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