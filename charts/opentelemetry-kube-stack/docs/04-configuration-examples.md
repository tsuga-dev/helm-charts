# Configuration Examples

This guide provides practical configuration examples for common scenarios and use cases. Each example includes explanations and can be adapted to your specific needs.

## Learning Objectives

- Understand different configuration patterns
- Learn how to customize collectors for specific needs
- See production-ready configurations
- Understand agent-only vs cluster-only deployments
- Learn advanced customization techniques

## Example 1: Minimal Setup

The simplest configuration for getting started quickly.

### Values File: `minimal.yaml`

```yaml
# Minimal configuration for testing
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key-here"

secret:
  create: true

serviceAccount:
  create: true

rbac:
  create: true

agent:
  enabled: true

cluster:
  enabled: true
```

### Installation

```bash
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  --create-namespace \
  -f minimal.yaml
```

**Use Case**: Development, testing, proof of concept

**Features**:
- Default resource limits
- Log collection enabled
- Standard receivers and processors

## Example 2: Production Configuration

Production-ready configuration with resource limits, security, and reliability.

### Values File: `production.yaml`

```yaml
# Production configuration with resource limits and security
tsuga:
  otlpEndpoint: "https://prod-tsuga-endpoint.com/v1/otlp"
  apiKey: "prod-api-key"  # Use secret management in production

secret:
  create: true

clusterName: "production-cluster"

serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/otel-role"  # For AWS IRSA

rbac:
  create: true

agent:
  enabled: true
  hostNetwork: true
  collectLogs: true
  collectOtelLogs: true
  collectNetwork: false  # Disable if not needed
  collectProcesses: false  # Disable if not needed

cluster:
  enabled: true

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi

nodeSelector:
  kubernetes.io/os: linux

tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/os
          operator: In
          values:
          - linux
```

### Installation

```bash
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  --create-namespace \
  -f production.yaml
```

**Use Case**: Production environments requiring reliability and performance

**Features**:
- Higher resource limits for performance
- Node affinity and tolerations
- Security annotations for cloud providers
- Selective metric collection

## Example 3: Agent-Only Deployment

Deploy only the Agent DaemonSet, useful for sending directly to backends.

### Values File: `agent-only.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

agent:
  enabled: true
  collectLogs: true

cluster:
  enabled: false  # Disable cluster receiver
```

**Use Case**: Simple setups, smaller clusters, direct forwarding

**Features**:
- Only DaemonSet deployment
- Agents forward directly to Tsuga
- Lower resource usage

## Example 4: Cluster-Only Deployment

Deploy only the Cluster Receiver, useful when agents are managed separately.

### Values File: `cluster-only.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

agent:
  enabled: false  # Disable agent

cluster:
  enabled: true
```

**Use Case**: Centralized collection from external sources

**Features**:
- Only Deployment (no DaemonSet)
- Centralized collection point
- Suitable for external telemetry sources

## Example 5: Custom Label Mapping

Configure custom label extraction from Kubernetes metadata.

### Values File: `custom-labels.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

clusterName: "production"

# Custom label mapping for k8sattributes processor
labelMapping:
  - tag_name: owner
    key: app.kubernetes.io/owner
    from: pod
  - tag_name: tier
    key: app.kubernetes.io/tier
    from: pod
  - tag_name: component
    key: app.kubernetes.io/component
    from: pod
  - tag_name: instance
    key: app.kubernetes.io/instance
    from: pod

agent:
  enabled: true
  collectLogs: true

cluster:
  enabled: true
```

**Use Case**: Rich metadata extraction for better observability

**Features**:
- Extracts Kubernetes labels as resource attributes
- Maps to Tsuga context attributes
- Enables filtering and grouping in Tsuga

## Example 6: Using Existing Secret

Use a pre-existing Kubernetes secret instead of creating one.

### Step 1: Create Secret Manually

```bash
kubectl create secret generic my-existing-secret \
  --from-literal=TSUGA_API_KEY="your-api-key" \
  --from-literal=TSUGA_OTLP_ENDPOINT="https://your-tsuga-endpoint.com/v1/otlp" \
  -n observability
```

### Step 2: Configure Values

```yaml
tsuga:
  otlpEndpoint: ""  # Will use secret value
  apiKey: ""  # Will use secret value

secret:
  create: false  # Don't create, use existing
  name: "my-existing-secret"  # Name of existing secret
  keyMapping:
    TSUGA_API_KEY: "TSUGA_API_KEY"  # Key name in existing secret
    TSUGA_OTLP_ENDPOINT: "TSUGA_OTLP_ENDPOINT"

agent:
  enabled: true

cluster:
  enabled: true
```

**Use Case**: Integration with external secret management systems

**Features**:
- Works with Sealed Secrets, External Secrets Operator
- Centralized secret management
- Supports secret rotation

## Example 7: Custom Receivers and Processors

Add custom receivers for specific data sources.

### Values File: `custom-receivers.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

agent:
  enabled: true
  config:
    # Add extra receivers
    extraReceivers:
      nginx:
        collection_interval: 10s
        endpoint: http://nginx-service.default:8081/status
      redis:
        collection_interval: 10s
        endpoint: redis-service.default:6379
        username: redis
      postgresql:
        endpoint: postgresql-service.default:5432
        username: postgres
        password: ${POSTGRES_PASSWORD}
        tls:
          insecure: true
        metrics:
          postgresql.deadlocks:
            enabled: true
          postgresql.tup_deleted:
            enabled: true
    # Add extra processors
    extraProcessors:
      filter:
        logs:
          exclude:
            match_type: regexp
            record_attributes:
              - key: level
                value: debug
    # Configure pipelines to use extra receivers
    service:
      pipelines:
        metrics:
          extraReceivers:
            - nginx
            - redis
            - postgresql
          extraProcessors:
            - filter
```

**Use Case**: Collecting metrics from specific services (databases, caches, etc.)

**Features**:
- Custom receiver configuration
- Additional processors for filtering/transformation
- Pipeline customization

## Example 8: High Availability

Configuration for production with high availability requirements.

### Values File: `high-availability.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

clusterName: "production"

agent:
  enabled: true
  hostNetwork: true

cluster:
  enabled: true
  # Configure cluster receiver for HA
  config:
    service:
      # Add replicas via OpenTelemetryCollector spec (not in config)

# Note: Replicas are set via OpenTelemetryCollector resource
# You may need to patch the resource after deployment:
# kubectl patch opentelemetrycollector my-otel-stack-cluster-receiver \
#   -n observability --type merge -p '{"spec":{"replicas":3}}'

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi

# Pod disruption budget would need to be created separately
```

**Use Case**: Critical production environments requiring redundancy

**Features**:
- Multiple cluster receiver replicas
- Higher resource allocation
- Node affinity for distribution

## Example 9: Resource-Constrained Environment

Optimized for limited resources (small clusters, edge deployments).

### Values File: `resource-constrained.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

agent:
  enabled: true
  collectLogs: false  # Disable log collection to save resources
  collectNetwork: false
  collectProcesses: false

cluster:
  enabled: true

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

**Use Case**: Small clusters, edge deployments, cost optimization

**Features**:
- Minimal resource usage
- Disabled optional collectors
- Essential observability only

## Example 10: Multi-Cluster Setup

Configuration for managing multiple clusters.

### Values File: `multi-cluster.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

# Unique cluster identifier
clusterName: "us-east-1-production"  # or "eu-west-1-staging"

agent:
  enabled: true
  collectLogs: true

cluster:
  enabled: true

# The clusterName will be added as k8s.cluster.name resource attribute
# This allows filtering and grouping by cluster in Tsuga
```

**Use Case**: Multi-cluster, multi-region observability

**Features**:
- Unique cluster identification
- Enables cross-cluster analysis in Tsuga
- Consistent configuration across clusters

## Example 11: Custom Exporters (Dual Export)

Export to both Tsuga and another backend.

### Values File: `dual-export.yaml`

```yaml
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key"

secret:
  create: true

agent:
  enabled: true
  config:
    extraExporters:
      # Export to Prometheus for local metrics
      prometheus:
        endpoint: "0.0.0.0:8889"
      # Export to another OTLP endpoint
      otlphttp/backup:
        endpoint: "https://backup-endpoint.com/v1/otlp"
        headers:
          Authorization: "Bearer ${BACKUP_API_KEY}"
    service:
      pipelines:
        metrics:
          extraExporters:
            - prometheus
            - otlphttp/backup
        traces:
          extraExporters:
            - otlphttp/backup
```

**Use Case**: Redundancy, multiple backends, gradual migration

**Features**:
- Multiple export destinations
- Backup/fallback capabilities
- Parallel processing

## Configuration Tips

### Understanding Configuration Behavior

1. **Replacement vs Extension**:
   - `config.receivers` - Replaces all default receivers
   - `config.extraReceivers` - Adds to default receivers

2. **Pipeline Configuration**:
   - `service.pipelines.metrics.extraReceivers` - Adds receivers to pipeline
   - Same pattern for processors and exporters

3. **Resource Inheritance**:
   - Component-specific resources override global
   - `agent.resources` overrides `resources`

### Best Practices

1. **Start Simple**: Begin with minimal config, add complexity as needed
2. **Use Values Files**: Version control your configurations
3. **Test Changes**: Validate with `helm template` before applying
4. **Monitor Resources**: Watch resource usage after changes
5. **Document Customizations**: Comment complex configurations

### Validating Configuration

```bash
# Dry-run to see rendered templates
helm template my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  -f your-values.yaml

# Lint your values
helm lint tsuga-charts/opentelemetry-kube-stack -f your-values.yaml

# Validate OpenTelemetry config syntax
kubectl get opentelemetrycollector -n observability -o yaml
```

## Next Steps

- **Troubleshoot Issues**: See [Troubleshooting Guide](05-troubleshooting.md)
- **Advanced Topics**: See [Advanced Topics Guide](06-advanced-topics.md)
- **Application Instrumentation**: See [Application Instrumentation Guide](03-application-instrumentation.md)

---

**Need help choosing a configuration?** Start with the minimal setup and add features as needed.

