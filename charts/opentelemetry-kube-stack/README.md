# OpenTelemetry Kubernetes Stack

A comprehensive Helm chart for deploying OpenTelemetry collectors with the Kubernetes operator, providing complete observability for Kubernetes environments with intelligent defaults and production-ready configurations.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Dual Deployment Pattern**: Implements the recommended OpenTelemetry architecture with both agent (DaemonSet) and cluster receiver (Deployment) components
- **Agent (DaemonSet)**: Collects host metrics, Kubernetes objects, and application telemetry from each node
- **Cluster Receiver (Deployment)**: Centralized collector that aggregates, processes, and forwards data to backends
- **Secret Management**: Configurable secrets for OpenTelemetry configuration with external secret support
- **RBAC Support**: Comprehensive service account and role-based access control
- **Resource Management**: Configurable resource limits and requests for both components
- **Host Metrics Collection**: Built-in support for node-level metrics collection
- **Kubernetes Objects Monitoring**: Automatic collection of pods, services, and other K8s resources
- **Comprehensive Observability**: Logs, metrics, and traces collection with intelligent defaults
- **Security First**: Built-in security best practices and credential management
- **Production Ready**: Optimized configurations for production environments

## Architecture

The chart implements the recommended OpenTelemetry architecture with two main components:

### Agent (DaemonSet)

- Runs on every node in the cluster
- Collects host metrics, Kubernetes objects, and application telemetry
- Forwards data to the cluster receiver or external backends
- Uses host networking for optimal performance

### Cluster Receiver (Deployment)

- Centralized collector that receives data from agents
- Processes and aggregates telemetry data
- Forwards processed data to external backends (e.g., Tsuga)
- Provides a single point of configuration for data processing

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- OpenTelemetry Operator installed in your cluster
- Valid Tsuga credentials (API key and endpoint)

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
EOF

# Install with values file
helm install my-otel-stack ./opentelemetry-kube-stack -f my-values.yaml
```

## Configuration

### Parameter Reference

The following table lists all configurable parameters and their default values:

#### Tsuga Configuration

| Parameter            | Description                            | Default | Required |
| -------------------- | -------------------------------------- | ------- | -------- |
| `tsuga.otlpEndpoint` | Tsuga OTLP endpoint for telemetry data | `""`    | Yes      |
| `tsuga.apiKey`       | Tsuga API key for authentication       | `""`    | Yes      |

#### Cluster Identification

| Parameter     | Description                                                         | Default | Required |
| ------------- | ------------------------------------------------------------------- | ------- | -------- |
| `clusterName` | Logical cluster name added as `k8s.cluster.name` resource attribute | `""`    | No       |

#### Label mapping

By default, both the agent and the Cluster Receiver are configured to map the following standard tsuga label

| Tag     | Otel Label                                | Tsuga attribute         |
| ------- | ----------------------------------------- | ----------------------- |
| service | resource.opentelemetry.io/service.name    | context.service.name    |
| env     | resource.opentelemetry.io/env             | context.env             |
| team    | resource.opentelemetry.io/team            | context.team            |
| version | resource.opentelemetry.io/service.version | context.service.version |


The `labelMapping` parameter adds extra label-to-attribute mappings for `k8sattributes` processor. These entries are appended under the `labels:` list.

Example for `labelMapping` (adds pod labels as resource attributes):

```yaml

labelMapping:
  - tag_name: owner
    key: app.kubernetes.io/owner
    from: pod
  - tag_name: tier
    key: app.kubernetes.io/tier
    from: pod
```

#### Secret Management

| Parameter                                | Description                                     | Default                                    |
| ---------------------------------------- | ----------------------------------------------- | ------------------------------------------ |
| `secret.create`                          | Create a secret for OpenTelemetry configuration | `false`                                    |
| `secret.name`                            | Name of the secret                              | `"otel-secret"`                            |
| `secret.keyMapping.TSUGA_API_KEY`        | Key mapping for API key in existing secret      | `"TSUGA_API_KEY"`                          |
| `secret.keyMapping.TSUGA_OTLP_ENDPOINT`  | Key mapping for endpoint in existing secret     | `"TSUGA_OTLP_ENDPOINT"`                    |
| `secret.validation.requireMandatoryKeys` | Require all mandatory keys to be present        | `true`                                     |
| `secret.validation.mandatoryKeys`        | List of mandatory keys                          | `["TSUGA_API_KEY", "TSUGA_OTLP_ENDPOINT"]` |

#### Agent Configuration

| Parameter                | Description                                     | Default                     |
| ------------------------ | ----------------------------------------------- | --------------------------- |
| `agent.enabled`          | Enable agent daemonset                          | `true`                      |
| `agent.hostNetwork`      | Enable host network for agent                   | `true`                      |
| `agent.image`            | OpenTelemetry Collector image                   | `""` (uses default)         |
| `agent.extraEnvs`        | Additional environment variables                | `[]`                        |
| `agent.collectLogs`      | Collect Kubernetes container logs via `filelog` | `true`                      |
| `agent.collectOtelLogs`  | Include collector's own logs in log collection  | `true`                      |
| `agent.collectNetwork`   | Collect host network metrics                    | `false`                     |
| `agent.collectProcesses` | Collect host process metrics                    | `false`                     |
| `agent.config`           | Agent collector configuration                   | See values.yaml             |
| `agent.resources`        | Agent-specific resource limits                  | `{}` (inherits from global) |
| `agent.nodeSelector`     | Agent-specific node selector                    | `{}` (inherits from global) |
| `agent.tolerations`      | Agent-specific tolerations                      | `[]` (inherits from global) |
| `agent.affinity`         | Agent-specific affinity rules                   | `{}` (inherits from global) |

**Configuration Behavior:**

- **`agent.config.receivers`**: Completely replaces the default receivers (filelog, jaeger, kubeletstats, hostmetrics, otlp, prometheus, zipkin)
- **`agent.config.extraReceivers`**: Adds additional receivers to the default ones
- **`agent.config.processors`**: Completely replaces the default processors (k8sattributes, memory_limiter, batch, cumulativetodelta, resource)
- **`agent.config.extraProcessors`**: Adds additional processors to the default ones
- **`agent.config.exporters`**: Completely replaces the default exporters (otlphttp/tsuga)
- **`agent.config.extraExporters`**: Adds additional exporters to the default ones
- **`agent.config.extraExtensions`**: Adds additional extensions to the default one (health_check)
- The same pattern applies to pipeline components: `extraReceivers`, `extraProcessors`, `extraExporters`, `extraExtensions` can be used within specific pipeline configurations

Advanced customization hooks supported under `agent.config`:

- `connectors`: Add or override connectors (e.g., `spanmetrics`). The chart enables `spanmetrics` by default and you can extend it here.
- `extensions` and `extraExtensions`: Extend the `extensions` block merged with the default `health_check`.
- `telemetry`: Override default `service.telemetry` (defaults to Prometheus on port 8888).
- `service.pipelines.<logs|metrics|traces>.extraReceivers`: Append receivers to the pipeline without replacing defaults.
- `service.pipelines.<logs|metrics|traces>.extraProcessors`: Append processors to the pipeline without replacing defaults.
- `service.pipelines.<logs|metrics|traces>.extraExporters`: Append exporters to the pipeline without replacing defaults.

#### Cluster Receiver Configuration

| Parameter           | Description                        | Default             |
| ------------------- | ---------------------------------- | ------------------- |
| `cluster.enabled`   | Enable cluster receiver deployment | `true`              |
| `cluster.image`     | OpenTelemetry Collector image      | `""` (uses default) |
| `cluster.extraEnvs` | Additional environment variables   | `[]`                |
| `cluster.config`    | Cluster receiver configuration     | See values.yaml     |

**Configuration Behavior:**

- **`cluster.config.receivers`**: Completely replaces the default receivers (`k8s_cluster`)
- **`cluster.config.extraReceivers`**: Adds additional receivers to the default ones
- **`cluster.config.processors`**: Completely replaces the default processors (defaults include `resource`, optional `k8sattributes`)
- **`cluster.config.extraProcessors`**: Adds additional processors to the default ones
- **`cluster.config.exporters`**: Completely replaces the default exporters (`otlphttp/tsuga`)
- **`cluster.config.extraExporters`**: Adds additional exporters to the default ones
- The same pattern applies to pipeline components: `extraReceivers`, `extraProcessors`, `extraExporters` can be used within specific pipeline configurations

Advanced customization hooks supported under `cluster.config`:

- `extensions` and `extraExtensions`
- `telemetry`
- `service.pipelines.metrics|logs/entity_events.extraReceivers`
- `service.pipelines.metrics|logs/entity_events.extraProcessors`
- `service.pipelines.metrics|logs/entity_events.extraExporters`

#### Resource Management

| Parameter                   | Description                   | Default |
| --------------------------- | ----------------------------- | ------- |
| `resources.limits.cpu`      | CPU limit for collectors      | `500m`  |
| `resources.limits.memory`   | Memory limit for collectors   | `512Mi` |
| `resources.requests.cpu`    | CPU request for collectors    | `100m`  |
| `resources.requests.memory` | Memory request for collectors | `128Mi` |

#### Node Selection and Scheduling

| Parameter      | Description                       | Default |
| -------------- | --------------------------------- | ------- |
| `nodeSelector` | Node selector for all components  | `{}`    |
| `tolerations`  | Tolerations for all components    | `[]`    |
| `affinity`     | Affinity rules for all components | `{}`    |

#### RBAC Configuration

| Parameter                    | Description                         | Default               |
| ---------------------------- | ----------------------------------- | --------------------- |
| `serviceAccount.create`      | Create a service account            | `true`                |
| `serviceAccount.name`        | Name of the service account         | `""` (auto-generated) |
| `serviceAccount.annotations` | Annotations for the service account | `{}`                  |
| `rbac.create`                | Create RBAC resources               | `true`                |

#### Validation

| Parameter                             | Description                       | Default |
| ------------------------------------- | --------------------------------- | ------- |
| `validation.enabled`                  | Enable resource name validation   | `true`  |
| `validation.maxNameLength`            | Maximum length for resource names | `63`    |
| `validation.enforceNamingConventions` | Enforce naming conventions        | `true`  |

### Default Configuration

The chart provides intelligent defaults for production use:

#### Agent (DaemonSet) - Node-Level Collection

**Receivers:**

- **Host Metrics**: CPU, memory, disk, filesystem, load, optional network and process metrics
- **Kubelet Stats**: Node and pod metrics via kubelet
- **Prometheus**: Scrapes application metrics from pods with `prometheus.io/scrape: true` annotation
- **OTLP**: Receives traces, metrics, and logs
- **Jaeger** and **Zipkin**: Receive traces via Jaeger and Zipkin protocols
- **File Logs**: Collects container logs from `/var/log/pods/*/*/*.log` (controlled by `agent.collectLogs`)

**Processors:**

- **K8s Attributes**: Enriches telemetry with Kubernetes metadata and selected pod labels
- **Memory Limiter**: Prevents memory issues (80% limit, 25% spike limit)
- **Batch**: Batches telemetry for efficient processing
- **Cumulative To Delta**: Converts cumulative counters to delta where applicable
- **Resource**: Adds attributes including `k8s.cluster.name` (from `clusterName`)

**Exporters:**

- **OTLP/Tsuga**: Forwards all telemetry to Tsuga endpoint with authentication

**Service Pipelines:**

- **Logs**: `otlp`, `filelog` → `k8sattributes`, `memory_limiter`, `batch`, `resource` → `otlphttp/tsuga`
- **Metrics**: `otlp`, `prometheus`, `kubeletstats`, `spanmetrics`, `hostmetrics` → `k8sattributes`, `memory_limiter`, `batch`, `cumulativetodelta`, `resource` → `otlphttp/tsuga`
- **Traces**: `otlp`, `jaeger`, `zipkin` → `k8sattributes`, `memory_limiter`, `batch`, `resource` → `otlphttp/tsuga`, `spanmetrics`

#### Cluster Receiver (Deployment) - Centralized Processing

**Receivers:**

- **Kubernetes Cluster**: Collects cluster-level metrics and entity events via `k8s_cluster`

**Processors:**

- **Resource**: Adds deployment/cluster attributes (defaults include `k8s.cluster.name`)

**Exporters:**

- **OTLP**: Forwards to Tsuga endpoint

**Service Pipelines:**

- **Metrics**: `k8s_cluster` → `resource` → `otlphttp/tsuga`
- **Entity Events (Logs)**: `k8s_cluster` → `resource` → `otlphttp/tsuga`

## Contributing

### Development Setup

1. **Fork the repository**
2. **Clone your fork:**

```bash
git clone https://github.com/your-username/otel_charts.git
cd otel_charts
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

5. **Test your changes:**

```bash
# Run tests
make test

# Lint templates
helm lint ./opentelemetry-kube-stack

# Test rendering
helm template test ./opentelemetry-kube-stack --debug
```

6. **Submit a pull request**

### Testing

#### Unit Tests

```bash
# Run unit tests
make test

# Run specific test
helm test my-otel-stack
```

#### Integration Tests

```bash
# Run integration tests
./tests/integration/test-deployment.sh
```

#### Security Tests

```bash
# Run security scan
./tests/security/security-scan.sh
```

### Code Style

- Use 2 spaces for YAML indentation
- Follow Helm best practices
- Add comments for complex logic
- Use descriptive variable names
- Follow semantic versioning

### Documentation

- Update README.md for new features
- Add examples for new configurations
- Update parameter tables
- Add troubleshooting steps for new features

## License

This chart is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.

## Support

For support and questions:

- Create an issue in the repository
- Check the troubleshooting section
- Review the OpenTelemetry documentation
- Join the OpenTelemetry community Slack
