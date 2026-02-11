# Auto-Instrumentation Testing Guide

This guide explains how to test the OpenTelemetry auto-instrumentation feature in the `opentelemetry-kube-stack` Helm chart.

## Overview

Auto-instrumentation allows applications to be automatically instrumented with OpenTelemetry without code changes. The chart creates an `Instrumentation` Custom Resource that the OpenTelemetry Operator uses to inject auto-instrumentation into pods.

## Test Components

### 1. Unit Tests (`tests/instrumentation_test.yaml`)

Helm unittest tests that validate template rendering and configuration:

- ✅ Resource creation when enabled/disabled
- ✅ Custom apiVersion support
- ✅ Custom naming with `nameOverride`
- ✅ Custom labels and annotations
- ✅ Spec passthrough for all languages (Java, Node.js, Python, .NET)
- ✅ Multiple language configurations
- ✅ Component labels
- ✅ Name length validation (63 character limit)
- ✅ Resource attributes
- ✅ Environment variables

#### Running Unit Tests

```bash
# Install helm unittest plugin (if not already installed)
helm plugin install https://github.com/quintush/helm-unittest

# Run all unit tests
cd charts/opentelemetry-kube-stack
helm unittest .

# Run only auto-instrumentation tests
helm unittest . -f tests/instrumentation_test.yaml

# Run with verbose output
helm unittest . -f tests/instrumentation_test.yaml -v
```

### 2. Integration Tests (`tests/integration/test-auto-instrumentation.sh`)

End-to-end integration tests that validate functionality in a live Kubernetes cluster:

- ✅ OpenTelemetry Operator installation check
- ✅ Instrumentation resource creation
- ✅ Configuration validation
- ✅ Auto-instrumentation injection into test applications
- ✅ Chart upgrade with configuration changes
- ✅ Disabling auto-instrumentation

#### Prerequisites

1. **Kubernetes Cluster**: Access to a Kubernetes cluster (can be local like minikube, kind, or k3d)
2. **kubectl**: Configured to access your cluster
3. **Helm**: Version 3.x
4. **OpenTelemetry Operator**: The script will install it automatically if not present

#### Running Integration Tests

```bash
# Run the integration test script
cd charts/opentelemetry-kube-stack
./tests/integration/test-auto-instrumentation.sh
```

The script will:
1. Check prerequisites
2. Install OpenTelemetry Operator (if needed)
3. Create a test namespace
4. Install the chart with auto-instrumentation enabled
5. Deploy test applications (Java and Node.js)
6. Verify instrumentation injection
7. Test chart upgrades
8. Test disabling auto-instrumentation
9. Clean up resources

### 3. Test Values File (`tests/values/auto-instrumentation.yaml`)

A comprehensive values file for manual testing and validation:

```bash
# Test with auto-instrumentation values
helm install my-test . \
  -f tests/values/auto-instrumentation.yaml \
  --set tsuga.otlpEndpoint="https://your-endpoint.com" \
  --set tsuga.apiKey="your-api-key"

# Verify the Instrumentation resource
kubectl get instrumentation

# View the configuration
kubectl get instrumentation <name> -o yaml
```

## Manual Testing Workflow

### Step 1: Enable Auto-Instrumentation

Install the chart with auto-instrumentation enabled:

```bash
helm install otel-test . \
  --set autoInstrumentation.enabled=true \
  --set autoInstrumentation.spec.exporter.endpoint="http://otel-test-opentelemetry-kube-stack-agent:4317" \
  --set autoInstrumentation.spec.java.image="ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest" \
  --set tsuga.otlpEndpoint="https://your-endpoint.com" \
  --set tsuga.apiKey="your-api-key"
```

### Step 2: Verify Instrumentation Resource

```bash
# List Instrumentation resources
kubectl get instrumentation

# Get detailed configuration
kubectl get instrumentation otel-test-opentelemetry-kube-stack-instrumentation -o yaml
```

### Step 3: Deploy Test Application

Create a test application with auto-instrumentation annotation:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-java-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-java-app
  template:
    metadata:
      labels:
        app: my-java-app
      annotations:
        # This annotation triggers auto-instrumentation
        instrumentation.opentelemetry.io/inject-java: "default/otel-test-opentelemetry-kube-stack-instrumentation"
    spec:
      containers:
      - name: app
        image: your-java-app:latest
        ports:
        - containerPort: 8080
```

Apply the deployment:

```bash
kubectl apply -f test-app.yaml
```

### Step 4: Verify Injection

Check that the OpenTelemetry Operator injected auto-instrumentation:

```bash
# Get the pod
kubectl get pods -l app=my-java-app

# Check for init container (should be opentelemetry-auto-instrumentation)
kubectl get pod <pod-name> -o jsonpath='{.spec.initContainers[*].name}'

# Check for OTEL environment variables
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[0].env[?(@.name=="OTEL_SERVICE_NAME")].value}'

# View full pod spec to see all injected configuration
kubectl get pod <pod-name> -o yaml | grep -A 20 "env:"
```

### Step 5: Verify Telemetry

Check that telemetry is being sent to the collector:

```bash
# Check collector logs
kubectl logs -l app.kubernetes.io/name=opentelemetry-kube-stack -l app.kubernetes.io/component=agent

# Check for traces from your application
kubectl logs -l app=my-java-app | grep -i "otel\|trace"
```

## Testing Different Languages

### Java Applications

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-java: "true"
```

### Node.js Applications

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-nodejs: "true"
```

### Python Applications

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-python: "true"
```

### .NET Applications

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-dotnet: "true"
```

### Go Applications

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-go: "true"
```

## Advanced Testing Scenarios

### Testing with Custom Configuration

```bash
helm install otel-test . \
  --set autoInstrumentation.enabled=true \
  --set autoInstrumentation.spec.exporter.endpoint="http://custom-collector:4317" \
  --set autoInstrumentation.spec.propagators[0]=tracecontext \
  --set autoInstrumentation.spec.propagators[1]=baggage \
  --set autoInstrumentation.spec.propagators[2]=b3 \
  --set autoInstrumentation.spec.sampler.type="parentbased_traceidratio" \
  --set autoInstrumentation.spec.sampler.argument="0.5" \
  --set tsuga.otlpEndpoint="https://your-endpoint.com" \
  --set tsuga.apiKey="your-api-key"
```

### Testing with Resource Attributes

```bash
helm install otel-test . \
  --set autoInstrumentation.enabled=true \
  --set autoInstrumentation.spec.resource.addK8sUIDAttributes=true \
  --set "autoInstrumentation.spec.resource.resourceAttributes.service\.namespace=production" \
  --set "autoInstrumentation.spec.resource.resourceAttributes.deployment\.environment=staging" \
  --set tsuga.otlpEndpoint="https://your-endpoint.com" \
  --set tsuga.apiKey="your-api-key"
```

### Testing Chart Upgrades

```bash
# Initial installation
helm install otel-test . -f tests/values/auto-instrumentation.yaml

# Upgrade with modified configuration
helm upgrade otel-test . \
  --set autoInstrumentation.spec.exporter.endpoint="http://new-endpoint:4317" \
  --set autoInstrumentation.labels.version=v2 \
  -f tests/values/auto-instrumentation.yaml

# Verify the update
kubectl get instrumentation -o yaml
```

### Testing Disabling Auto-Instrumentation

```bash
# Disable auto-instrumentation
helm upgrade otel-test . --set autoInstrumentation.enabled=false

# Verify Instrumentation resource is removed
kubectl get instrumentation  # Should return empty
```

## Troubleshooting

### Instrumentation Resource Not Created

1. Check if auto-instrumentation is enabled:
   ```bash
   helm get values otel-test | grep -A 5 autoInstrumentation
   ```

2. Check Helm release for errors:
   ```bash
   helm status otel-test
   ```

3. Check for validation errors:
   ```bash
   kubectl describe instrumentation
   ```

### Auto-Instrumentation Not Injected

1. **Check Operator Status**:
   ```bash
   kubectl get pods -n opentelemetry-operator-system
   kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator
   ```

2. **Verify Annotation Format**:
   - Format: `instrumentation.opentelemetry.io/inject-<language>: "true"`
   - Or with namespace: `instrumentation.opentelemetry.io/inject-<language>: "namespace/instrumentation-name"`

3. **Check Operator Webhook**:
   ```bash
   kubectl get mutatingwebhookconfigurations
   ```

4. **Check Pod Events**:
   ```bash
   kubectl describe pod <pod-name>
   ```

### Wrong Instrumentation Configuration

1. **Check Instrumentation Resource**:
   ```bash
   kubectl get instrumentation <name> -o yaml
   ```

2. **Verify Helm Values**:
   ```bash
   helm get values otel-test
   ```

3. **Check Template Rendering**:
   ```bash
   helm template otel-test . -f tests/values/auto-instrumentation.yaml | grep -A 50 "kind: Instrumentation"
   ```

## CI/CD Integration

Add auto-instrumentation tests to your CI/CD pipeline:

```yaml
# .github/workflows/test.yml
- name: Run Auto-Instrumentation Unit Tests
  run: |
    helm plugin install https://github.com/quintush/helm-unittest
    helm unittest charts/opentelemetry-kube-stack -f tests/instrumentation_test.yaml

- name: Run Auto-Instrumentation Integration Tests
  run: |
    cd charts/opentelemetry-kube-stack
    ./tests/integration/test-auto-instrumentation.sh
```

## Best Practices

1. **Always use namespaced references** in annotations when you have multiple Instrumentation resources
2. **Test with realistic configurations** that match your production setup
3. **Verify telemetry is actually being sent** by checking collector logs
4. **Test upgrades** to ensure configuration changes are applied correctly
5. **Test with multiple languages** if your environment uses polyglot applications
6. **Monitor resource usage** of instrumented applications (auto-instrumentation adds overhead)
7. **Use sampling** in production to reduce overhead and costs

## References

- [OpenTelemetry Operator Documentation](https://github.com/open-telemetry/opentelemetry-operator)
- [Instrumentation API Reference](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#instrumentation)
- [Auto-Instrumentation Annotations](https://github.com/open-telemetry/opentelemetry-operator#opentelemetry-auto-instrumentation-injection)
- [Helm Unittest Plugin](https://github.com/quintush/helm-unittest)
