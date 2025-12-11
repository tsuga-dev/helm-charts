# Advanced Topics

This guide covers advanced configuration scenarios, optimization techniques, and production best practices for the OpenTelemetry Kubernetes Stack.

## Learning Objectives

- Understand advanced collector configuration
- Learn pipeline customization techniques
- Implement multi-cluster observability
- Configure high availability setups
- Apply security best practices
- Optimize performance and costs

## Custom Collector Configuration

### Overriding Default Configuration

The chart provides hooks for customizing collectors without replacing defaults entirely.

#### Complete Replacement

Replace all default receivers, processors, or exporters:

```yaml
agent:
  config:
    receivers:
      # This REPLACES all default receivers
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
      prometheus:
        config:
          scrape_configs:
            - job_name: custom
              scrape_interval: 30s
```

#### Extending Defaults

Add to defaults using `extraReceivers`, `extraProcessors`, etc.:

```yaml
agent:
  config:
    # This ADDS to default receivers
    extraReceivers:
      redis:
        endpoint: redis:6379
      mysql:
        endpoint: mysql:3306
    service:
      pipelines:
        metrics:
          # This ADDS to default receivers in pipeline
          extraReceivers:
            - redis
            - mysql
```

### Custom Processors

Add advanced processing capabilities:

```yaml
agent:
  config:
    extraProcessors:
      # Filter sensitive data
      filter:
        logs:
          exclude:
            match_type: regexp
            record_attributes:
              - key: message
                value: "(?i)(password|secret|key)"
      
      # Add custom attributes
      resource:
        attributes:
          - key: deployment.environment
            value: production
            action: upsert
      
      # Sampling for high-volume traces
      probabilistic_sampler:
        sampling_percentage: 10
      
      # Transform attributes
      transform:
        log_statements:
          - context: log
            statements:
              - set(severity_text, "INFO") where severity_number < 9
```

### Custom Exporters

Export to multiple backends or add custom processing:

```yaml
agent:
  config:
    extraExporters:
      # Export to file for debugging
      file:
        path: /tmp/otel-data.jsonl
      
      # Export to another OTLP endpoint
      otlphttp/backup:
        endpoint: https://backup-endpoint.com/v1/otlp
        headers:
          Authorization: Bearer ${BACKUP_API_KEY}
      
      # Export metrics to Prometheus
      prometheus:
        endpoint: 0.0.0.0:8889
      
      # Export traces to Jaeger
      jaeger:
        endpoint: jaeger:14250
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          extraExporters:
            - file
            - otlphttp/backup
```

## Pipeline Customization

### Multi-Pipeline Configuration

Create separate pipelines for different data types:

```yaml
agent:
  config:
    service:
      pipelines:
        # High-priority traces pipeline
        traces/important:
          receivers: [otlp]
          processors: [memory_limiter, batch, resource]
          exporters: [otlphttp/tsuga]
        
        # Lower-priority traces with sampling
        traces/bulk:
          receivers: [otlp]
          processors: [memory_limiter, probabilistic_sampler, batch, resource]
          exporters: [otlphttp/tsuga]
        
        # Metrics pipeline with aggregation
        metrics:
          receivers: [otlp, prometheus, kubeletstats]
          processors: [memory_limiter, batch, cumulativetodelta, resource]
          exporters: [otlphttp/tsuga]
        
        # Logs pipeline with filtering
        logs:
          receivers: [otlp, filelog]
          processors: [filter, memory_limiter, batch, resource]
          exporters: [otlphttp/tsuga]
```

### Connectors

Use connectors to link pipelines:

```yaml
agent:
  config:
    connectors:
      # Span metrics connector
      spanmetrics:
        metrics_exporter: otlphttp/tsuga
        latency_histogram_buckets: [100us, 1ms, 2ms, 6ms, 10ms, 100ms, 250ms]
        dimensions:
          - name: http.method
            default: GET
          - name: http.status_code
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch, resource]
          exporters: [spanmetrics, otlphttp/tsuga]
        metrics:
          receivers: [spanmetrics]
          processors: [memory_limiter, batch, resource]
          exporters: [otlphttp/tsuga]
```

## Multi-Cluster Setup

### Centralized Observability

Configure multiple clusters to send data to the same Tsuga instance:

```yaml
# Cluster 1: us-east-1
clusterName: "us-east-1-production"

tsuga:
  otlpEndpoint: "https://central-tsuga.com/v1/otlp"
  apiKey: "shared-api-key"

# Cluster 2: eu-west-1
clusterName: "eu-west-1-production"

tsuga:
  otlpEndpoint: "https://central-tsuga.com/v1/otlp"
  apiKey: "shared-api-key"

# Cluster 3: ap-south-1
clusterName: "ap-south-1-staging"

tsuga:
  otlpEndpoint: "https://central-tsuga.com/v1/otlp"
  apiKey: "shared-api-key"
```

### Cluster Identification

The `clusterName` value is added as `k8s.cluster.name` resource attribute, enabling:

- Filtering by cluster in Tsuga
- Cross-cluster correlation
- Cluster-specific dashboards
- Multi-cluster alerting

### Regional Configuration

Adjust configuration per cluster characteristics:

```yaml
# High-traffic cluster
resources:
  limits:
    cpu: 2000m
    memory: 2Gi

# Low-traffic cluster
resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

## High Availability

### Cluster Receiver Replicas

Ensure cluster receiver has multiple replicas:

```bash
# After deployment, patch to add replicas
kubectl patch opentelemetrycollector my-otel-stack-cluster-receiver \
  -n observability --type merge -p '{"spec":{"replicas":3}}'

# Or use autoscaling
kubectl autoscale opentelemetrycollector my-otel-stack-cluster-receiver \
  -n observability --min=2 --max=5 --cpu-percent=80
```

### Pod Disruption Budget

Create PDB to ensure availability during updates:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: otel-cluster-receiver-pdb
  namespace: observability
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/component: cluster-receiver
```

### Node Distribution

Use affinity to distribute pods across nodes:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/component
                operator: In
                values:
                  - cluster-receiver
          topologyKey: kubernetes.io/hostname
```

## Security Best Practices

### Secret Management

#### Using External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: otel-tsuga-secret
  namespace: observability
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: my-otel-stack-otel-secret
    creationPolicy: Owner
  data:
    - secretKey: TSUGA_API_KEY
      remoteRef:
        key: tsuga/api-key
    - secretKey: TSUGA_OTLP_ENDPOINT
      remoteRef:
        key: tsuga/endpoint
```

#### Using Sealed Secrets

```bash
# Encrypt secret
kubeseal < secret.yaml > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml

# Configure chart to use existing secret
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --set secret.create=false \
  --set secret.name=my-otel-stack-otel-secret
```

### Network Policies

Restrict network access:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: otel-agent-policy
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: agent
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 4317  # OTLP gRPC
        - protocol: TCP
          port: 4318  # OTLP HTTP
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: cluster-receiver
      ports:
        - protocol: TCP
          port: 4318
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              app.kubernetes.io/name: opentelemetry-kube-stack
              app.kubernetes.io/component: cluster-receiver
```

### RBAC Minimization

Use least-privilege RBAC:

```yaml
rbac:
  create: true
  # The chart creates minimal required permissions
  # Review and adjust ClusterRole if needed
```

### TLS Configuration

Enable TLS for OTLP endpoints:

```yaml
agent:
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
            tls:
              cert_file: /etc/tls/server.crt
              key_file: /etc/tls/server.key
```

## Performance Optimization

### Resource Tuning

#### CPU Optimization

```yaml
resources:
  limits:
    cpu: 1000m
  requests:
    cpu: 200m  # Minimum for steady state

# For batch processing, prefer fewer cores with more batch size
agent:
  config:
    processors:
      batch:
        send_batch_size: 1024  # Larger batches = fewer CPU cycles
```

#### Memory Optimization

```yaml
resources:
  limits:
    memory: 1Gi
  requests:
    memory: 256Mi

agent:
  config:
    processors:
      memory_limiter:
        limit_percentage: 75  # Leave headroom
        spike_limit_percentage: 20
        check_interval: 1s
```

### Batch Configuration

Optimize batching for your workload:

```yaml
agent:
  config:
    processors:
      batch:
        # High throughput: larger batches, longer timeout
        timeout: 5s
        send_batch_size: 2048
        send_batch_max_size: 4096
        
        # OR: Low latency: smaller batches, shorter timeout
        # timeout: 100ms
        # send_batch_size: 100
        # send_batch_max_size: 200
```

### Sampling

Reduce volume with sampling:

```yaml
agent:
  config:
    extraProcessors:
      probabilistic_sampler:
        sampling_percentage: 10  # Sample 10% of traces
      
      tail_sampling:
        decision_wait: 10s
        num_traces: 100
        policies:
          - name: error-policy
            type: status_code
            status_code:
              status_codes: [ERROR]
          - name: slow-policy
            type: latency
            latency:
              threshold_ms: 500
```

### Selective Collection

Disable unnecessary collection:

```yaml
agent:
  collectLogs: false  # If you have centralized logging
  collectNetwork: false  # If not needed
  collectProcesses: false  # If not needed
  collectOtelLogs: false  # If not debugging
```

## Cost Optimization

### Reduce Data Volume

```yaml
agent:
  config:
    extraProcessors:
      # Filter verbose logs
      filter:
        logs:
          exclude:
            match_type: regexp
            record_attributes:
              - key: level
                value: debug
      
      # Sample high-volume traces
      probabilistic_sampler:
        sampling_percentage: 5
```

### Use Sampling

Sample based on business value:

```yaml
agent:
  config:
    extraProcessors:
      tail_sampling:
        policies:
          # Keep all errors
          - name: keep-errors
            type: status_code
            status_code:
              status_codes: [ERROR]
          # Sample 10% of successful requests
          - name: sample-success
            type: probabilistic
            probabilistic:
              sampling_percentage: 10
```

## Monitoring the Observability Stack

### Self-Monitoring

Monitor the collectors themselves:

```yaml
agent:
  config:
    service:
      telemetry:
        metrics:
          readers:
            - pull:
                exporter:
                  prometheus:
                    host: 0.0.0.0
                    port: 8888
                    endpoint: /metrics
```

### Alerting Rules

Create Prometheus alerts for collector health:

```yaml
groups:
  - name: otel-collector
    rules:
      - alert: OtelCollectorDown
        expr: up{job="otel-collector"} == 0
        for: 5m
        
      - alert: OtelCollectorHighMemory
        expr: otelcol_memory_usage / otelcol_memory_limit > 0.9
        for: 5m
```

## Advanced Use Cases

### Custom Resource Attributes

Add deployment-specific attributes:

```yaml
agent:
  config:
    processors:
      resource:
        attributes:
          - key: deployment.region
            value: us-east-1
            action: upsert
          - key: deployment.team
            value: platform
            action: upsert
          - key: deployment.cost-center
            value: engineering
            action: upsert
```

### Attribute Transformation

Transform attributes before export:

```yaml
agent:
  config:
    extraProcessors:
      transform:
        trace_statements:
          - context: span
            statements:
              # Add custom attribute
              - set(attributes["deployment.environment"], "production")
              # Rename attribute
              - set(attributes["service.name"], attributes["service.namespace"])
```

### Custom Metrics

Derive custom metrics from traces:

```yaml
agent:
  config:
    connectors:
      spanmetrics:
        metrics_exporter: otlphttp/tsuga
        dimensions:
          - name: http.method
          - name: http.status_code
          - name: deployment.environment
```

## Best Practices Summary

1. **Start Simple**: Begin with defaults, add complexity gradually
2. **Monitor Resources**: Watch CPU/memory usage after changes
3. **Test Changes**: Use `helm template` to validate before applying
4. **Version Control**: Keep configuration in Git
5. **Document Customizations**: Comment complex configurations
6. **Regular Updates**: Keep charts and operators updated
7. **Security First**: Use external secret management
8. **Cost Awareness**: Implement sampling and filtering
9. **High Availability**: Use multiple replicas and PDBs
10. **Self-Monitoring**: Monitor your observability stack

## Next Steps

- Review [Configuration Examples](04-configuration-examples.md) for practical patterns
- Check [Troubleshooting Guide](05-troubleshooting.md) for common issues
- Explore [Application Instrumentation](03-application-instrumentation.md) for app-level setup

---

**Ready to optimize?** Start with resource tuning and sampling, then move to advanced features as needed.

