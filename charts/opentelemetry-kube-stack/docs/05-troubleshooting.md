# Troubleshooting Guide

This guide helps you diagnose and resolve common issues when deploying and operating the OpenTelemetry Kubernetes Stack.

## Learning Objectives

- Identify common deployment issues
- Verify correct operation
- Diagnose telemetry flow problems
- Resolve configuration errors
- Optimize performance

## Pre-Troubleshooting Checklist

Before diving into specific issues, verify the basics:

- [ ] OpenTelemetry Operator is installed and running
- [ ] Helm chart is installed successfully
- [ ] All pods are in `Running` state
- [ ] Secret contains correct credentials
- [ ] Network connectivity to Tsuga endpoint
- [ ] Sufficient cluster resources

## Common Issues and Solutions

### Issue 1: Operator Not Installed or Not Running

**Symptoms**:
- OpenTelemetryCollector resources stuck in `Pending`
- No collector pods created
- Error: `no matches for kind "OpenTelemetryCollector"`

**Diagnosis**:

```bash
# Check if operator is installed
kubectl get pods -n opentelemetry-operator-system

# Check operator logs
kubectl logs -n opentelemetry-operator-system \
  -l control-plane=controller-manager
```

**Solutions**:

```bash
# Install the operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n opentelemetry-operator-system \
  --timeout=90s

# Verify CRDs are installed
kubectl get crd opentelemetrycollectors.opentelemetry.io
```

### Issue 2: Pods Not Starting (CrashLoopBackOff)

**Symptoms**:
- Pods in `CrashLoopBackOff` state
- Frequent restarts
- Error logs in pod events

**Diagnosis**:

```bash
# Check pod status
kubectl get pods -n observability

# Describe pod for events
kubectl describe pod <pod-name> -n observability

# Check pod logs
kubectl logs <pod-name> -n observability --previous
```

**Common Causes and Solutions**:

1. **Invalid Configuration**:
   ```bash
   # Check OpenTelemetryCollector config
   kubectl get opentelemetrycollector -n observability -o yaml
   
   # Look for validation errors in logs
   kubectl logs -n observability <pod-name> | grep -i error
   ```

2. **Missing Secret**:
   ```bash
   # Verify secret exists
   kubectl get secret -n observability
   
   # Check secret keys
   kubectl get secret my-otel-stack-otel-secret -n observability -o jsonpath='{.data}' | jq
   ```

3. **Resource Constraints**:
   ```bash
   # Check node resources
   kubectl top nodes
   
   # Check pod resource requests
   kubectl describe pod <pod-name> -n observability | grep -A 5 "Requests:"
   ```

### Issue 3: No Data Reaching Tsuga

**Symptoms**:
- Collectors running but no data in Tsuga
- No errors in logs
- Connectivity appears fine

**Diagnosis**:

```bash
# Check cluster receiver logs for export attempts
kubectl logs -n observability \
  -l app.kubernetes.io/component=cluster-receiver \
  --tail=100 | grep -i export

# Check for authentication errors
kubectl logs -n observability \
  -l app.kubernetes.io/component=cluster-receiver \
  --tail=100 | grep -i auth

# Verify endpoint configuration
kubectl exec -n observability \
  $(kubectl get pods -n observability -l app.kubernetes.io/component=cluster-receiver -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep TSUGA
```

**Solutions**:

1. **Verify Endpoint**:
   ```bash
   # Test connectivity from cluster
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     curl -v https://your-tsuga-endpoint.com/v1/otlp
   ```

2. **Check API Key**:
   ```bash
   # Verify API key in secret
   kubectl get secret my-otel-stack-otel-secret -n observability \
     -o jsonpath='{.data.TSUGA_API_KEY}' | base64 -d
   ```

3. **Test Export Directly**:
   ```bash
   # Send test trace from pod
   kubectl run -it --rm test-otel --image=otel/opentelemetry-collector --restart=Never -- \
     /bin/sh -c 'echo "Test trace"'
   ```

### Issue 4: Agent Pods Not on All Nodes

**Symptoms**:
- DaemonSet desired count doesn't match node count
- Some nodes missing agent pods
- `NotReady` or `Unavailable` pods

**Diagnosis**:

```bash
# Check DaemonSet status
kubectl get daemonset -n observability

# Check why pods aren't scheduled
kubectl describe pod <pod-name> -n observability | grep -A 10 "Events:"

# Check node conditions
kubectl get nodes
```

**Solutions**:

1. **Node Selector Issues**:
   ```bash
   # Check if nodeSelector is too restrictive
   kubectl get daemonset -n observability -o yaml | grep nodeSelector
   
   # Adjust nodeSelector if needed
   helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
     --set nodeSelector={} \
     --reuse-values
   ```

2. **Taints/Tolerations**:
   ```bash
   # Check node taints
   kubectl describe node <node-name> | grep Taint
   
   # Add tolerations if needed
   helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
     --set tolerations[0].key=node-role.kubernetes.io/control-plane \
     --set tolerations[0].operator=Exists \
     --set tolerations[0].effect=NoSchedule \
     --reuse-values
   ```

3. **Resource Constraints**:
   ```bash
   # Check node capacity
   kubectl describe node <node-name> | grep -A 5 "Allocatable:"
   ```

### Issue 5: High Memory Usage

**Symptoms**:
- Pods getting OOMKilled
- High memory consumption
- Performance degradation

**Diagnosis**:

```bash
# Check current memory usage
kubectl top pods -n observability

# Check memory limits
kubectl get pod -n observability -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}'

# Check memory limiter processor logs
kubectl logs -n observability \
  -l app.kubernetes.io/component=agent \
  --tail=100 | grep -i memory
```

**Solutions**:

1. **Increase Resource Limits**:
   ```bash
   helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
     --set resources.limits.memory=1Gi \
     --set resources.requests.memory=512Mi \
     --reuse-values
   ```

2. **Adjust Memory Limiter**:
   ```yaml
   agent:
     config:
       processors:
         memory_limiter:
           check_interval: 1s
           limit_percentage: 75  # Reduce if needed
           spike_limit_percentage: 20
   ```

3. **Reduce Collection Scope**:
   ```bash
   # Disable log collection if not needed
   helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
     --set agent.collectLogs=false \
     --reuse-values
   ```

### Issue 6: Application Traces Not Appearing

**Symptoms**:
- Application sends telemetry but nothing appears in Tsuga
- Agent logs show no incoming traces
- Network connectivity issues

**Diagnosis**:

```bash
# Check if agent is receiving traces
kubectl logs -n observability \
  -l app.kubernetes.io/component=agent \
  --tail=100 | grep -i trace

# Verify agent service
kubectl get svc -n observability | grep agent

# Test connectivity from application pod
kubectl exec -n <app-namespace> <app-pod> -- \
  curl -v http://my-otel-stack-agent.observability.svc.cluster.local:4318
```

**Solutions**:

1. **Verify Service DNS**:
   ```bash
   # Check service exists
   kubectl get svc -n observability
   
   # Test DNS resolution
   kubectl run -it --rm debug --image=busybox --restart=Never -- \
     nslookup my-otel-stack-agent.observability.svc.cluster.local
   ```

2. **Check Endpoint Configuration**:
   ```bash
   # Verify endpoint in application
   kubectl exec -n <app-namespace> <app-pod> -- env | grep OTEL
   ```

3. **Verify Network Policies**:
   ```bash
   # Check for network policies blocking traffic
   kubectl get networkpolicy -n observability
   kubectl get networkpolicy -n <app-namespace>
   ```

### Issue 7: Logs Not Being Collected

**Symptoms**:
- Container logs not appearing in Tsuga
- Filelog receiver errors
- No log pipeline activity

**Diagnosis**:

```bash
# Check if log collection is enabled
kubectl get opentelemetrycollector -n observability \
  -l app.kubernetes.io/component=agent -o yaml | grep -i filelog

# Check agent logs for filelog errors
kubectl logs -n observability \
  -l app.kubernetes.io/component=agent \
  --tail=100 | grep -i filelog

# Verify volume mounts
kubectl describe pod -n observability \
  -l app.kubernetes.io/component=agent | grep -A 5 "Mounts:"
```

**Solutions**:

1. **Enable Log Collection**:
   ```bash
   helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
     --set agent.collectLogs=true \
     --reuse-values
   ```

2. **Check Host Path Access**:
   ```bash
   # Verify /var/log/pods exists on nodes
   kubectl debug node/<node-name> -it --image=busybox -- \
     ls -la /var/log/pods
   ```

3. **Verify RBAC Permissions**:
   ```bash
   # Check service account permissions
   kubectl get clusterrolebinding | grep my-otel-stack
   ```

### Issue 8: Authentication Failures

**Symptoms**:
- 401 Unauthorized errors in logs
- Authentication failures to Tsuga
- Export errors

**Diagnosis**:

```bash
# Check cluster receiver logs
kubectl logs -n observability \
  -l app.kubernetes.io/component=cluster-receiver \
  --tail=100 | grep -i "401\|unauthorized\|auth"

# Verify API key format
kubectl get secret my-otel-stack-otel-secret -n observability \
  -o jsonpath='{.data.TSUGA_API_KEY}' | base64 -d | wc -c
```

**Solutions**:

1. **Verify API Key**:
   ```bash
   # Check if API key is correct
   kubectl get secret my-otel-stack-otel-secret -n observability \
     -o jsonpath='{.data.TSUGA_API_KEY}' | base64 -d
   
   # Recreate secret if wrong
   kubectl create secret generic my-otel-stack-otel-secret \
     --from-literal=TSUGA_API_KEY="correct-api-key" \
     --from-literal=TSUGA_OTLP_ENDPOINT="https://endpoint.com/v1/otlp" \
     -n observability --dry-run=client -o yaml | kubectl apply -f -
   ```

2. **Check Header Format**:
   ```bash
   # Verify exporter configuration
   kubectl get opentelemetrycollector -n observability \
     -l app.kubernetes.io/component=cluster-receiver -o yaml | grep -A 5 "Authorization"
   ```

## Verification Commands

### Health Check Script

```bash
#!/bin/bash
NAMESPACE="observability"
RELEASE="my-otel-stack"

echo "=== Operator Status ==="
kubectl get pods -n opentelemetry-operator-system

echo -e "\n=== Collector Pods ==="
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-kube-stack

echo -e "\n=== DaemonSet Status ==="
kubectl get daemonset -n $NAMESPACE

echo -e "\n=== Deployment Status ==="
kubectl get deployment -n $NAMESPACE

echo -e "\n=== Secret Status ==="
kubectl get secret -n $NAMESPACE | grep otel

echo -e "\n=== Service Status ==="
kubectl get svc -n $NAMESPACE

echo -e "\n=== Recent Agent Logs ==="
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=agent --tail=20

echo -e "\n=== Recent Cluster Receiver Logs ==="
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=cluster-receiver --tail=20
```

### Export Test

```bash
# Test OTLP export from cluster
kubectl run -it --rm otlp-test --image=otel/opentelemetry-collector --restart=Never -- \
  /bin/sh -c '
    cat > /tmp/config.yaml << EOF
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
    
    exporters:
      otlphttp:
        endpoint: ${TSUGA_OTLP_ENDPOINT}
        headers:
          Authorization: Bearer ${TSUGA_API_KEY}
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [otlphttp]
    EOF
    /otelcol --config=/tmp/config.yaml
  '
```

## Performance Tuning

### High Throughput Scenarios

```yaml
agent:
  config:
    processors:
      batch:
        timeout: 1s
        send_batch_size: 512
        send_batch_max_size: 1024
      memory_limiter:
        check_interval: 0.5s
        limit_percentage: 80
        spike_limit_percentage: 25

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

### Low Latency Requirements

```yaml
agent:
  config:
    processors:
      batch:
        timeout: 100ms
        send_batch_size: 100
```

## Debugging Tips

1. **Use `helm template`** to see rendered configuration:
   ```bash
   helm template my-otel-stack tsuga-charts/opentelemetry-kube-stack \
     -f values.yaml | grep -A 10 "config:"
   ```

2. **Check OpenTelemetryCollector resource**:
   ```bash
   kubectl get opentelemetrycollector -n observability -o yaml
   ```

3. **Enable debug logging**:
   ```yaml
   agent:
     config:
       service:
         telemetry:
           logs:
             level: debug
   ```

4. **Compare working vs non-working configs**:
   ```bash
   # Export current config
   kubectl get opentelemetrycollector -n observability -o yaml > current-config.yaml
   ```

## Getting Additional Help

If issues persist:

1. **Collect Diagnostic Information**:
   ```bash
   # Export all relevant resources
   kubectl get all,opentelemetrycollector,secret,svc -n observability -o yaml > diagnostics.yaml
   ```

2. **Check Operator Logs**:
   ```bash
   kubectl logs -n opentelemetry-operator-system -l control-plane=controller-manager
   ```

3. **Review Chart Documentation**:
   - [Configuration Examples](04-configuration-examples.md)
   - [Advanced Topics](06-advanced-topics.md)

4. **OpenTelemetry Community**:
   - OpenTelemetry Operator: https://github.com/open-telemetry/opentelemetry-operator/issues
   - OpenTelemetry Collector: https://github.com/open-telemetry/opentelemetry-collector-contrib/issues

---

**Still stuck?** Review the [Configuration Examples](04-configuration-examples.md) or [Advanced Topics](06-advanced-topics.md) for more details.

