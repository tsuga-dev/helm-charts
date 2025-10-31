# Application Instrumentation Guide

This guide explains how to instrument your applications to send telemetry data (traces, metrics, and logs) to OpenTelemetry Collectors in your Kubernetes cluster, which then forward the data to Tsuga.

## Learning Objectives

- Understand different instrumentation approaches
- Learn how to use auto-instrumentation with the OpenTelemetry Operator
- Understand manual SDK instrumentation
- Configure OTLP endpoints for applications
- Set up resource attributes and label mapping
- See code examples for common languages

## Overview of Instrumentation Approaches

There are two main approaches to instrumenting applications:

1. **Auto-instrumentation**: Automatic code injection without modifying application code
2. **Manual Instrumentation**: Using OpenTelemetry SDKs in your application code

### When to Use Each Approach

**Auto-instrumentation** is ideal for:
- Existing applications without instrumentation
- Quick observability setup
- Applications using supported frameworks/libraries
- Minimal code changes required

**Manual Instrumentation** is ideal for:
- Fine-grained control over spans and metrics
- Custom business logic instrumentation
- Applications not supported by auto-instrumentation
- Custom attributes and events

## How Applications Connect to Collectors

Applications send telemetry via OTLP (OpenTelemetry Protocol) to the Agent running on each node. The Agent is accessible via:

- **Service DNS**: `<release-name>-agent.<namespace>.svc.cluster.local`
- **Pod IP** (when using hostNetwork): Available via environment variables
- **Localhost**: When agent runs with hostNetwork, applications can use `localhost`

### Default OTLP Endpoints

The Agent exposes OTLP endpoints by default:

- **OTLP gRPC**: Port `4317`
- **OTLP HTTP**: Port `4318`
- **Jaeger gRPC**: Port `14250`
- **Jaeger Thrift UDP**: Port `6831`
- **Jaeger Thrift HTTP**: Port `14268`
- **Zipkin**: Port `9411`

## Method 1: Auto-Instrumentation with OpenTelemetry Operator

The OpenTelemetry Operator can automatically inject instrumentation into your application pods without modifying code.

### Step 1: Create Instrumentation Resource

Create an `Instrumentation` resource that defines how auto-instrumentation should work:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: Instrumentation
metadata:
  name: my-instrumentation
  namespace: default
spec:
  exporter:
    endpoint: http://my-otel-stack-agent.observability.svc.cluster.local:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:latest
```

Apply it:

```bash
kubectl apply -f instrumentation.yaml
```

### Step 2: Annotate Your Deployment

Add annotations to your application deployment to enable auto-instrumentation:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-java: "true"
        instrumentation.opentelemetry.io/inject-python: "true"
        instrumentation.opentelemetry.io/inject-nodejs: "true"
        # ... other language annotations
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        # ... other container config
```

### Step 3: Specify Instrumentation Resource

If your Instrumentation resource is in a different namespace:

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-java: "my-instrumentation"
```

### Supported Languages

Auto-instrumentation supports:
- **Java**: Spring Boot, JAX-RS, servlets, and more
- **Node.js**: Express, Fastify, HTTP, and more
- **Python**: Django, Flask, FastAPI, and more
- **.NET**: ASP.NET Core, HttpClient, and more
- **Go**: Limited support
- **Ruby**: Rack, Rails

## Method 2: Manual SDK Instrumentation

For full control, use OpenTelemetry SDKs directly in your application code.

### Finding the OTLP Endpoint

Applications need to discover the Agent endpoint. Options:

#### Option A: Use Service DNS (Recommended)

```bash
# Agent service DNS pattern
<release-name>-agent.<namespace>.svc.cluster.local
```

Example:
```
my-otel-stack-agent.observability.svc.cluster.local
```

#### Option B: Use Environment Variable

The Agent exposes `MY_POD_IP` environment variable when using hostNetwork. You can create a ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-config
data:
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://my-otel-stack-agent.observability.svc.cluster.local:4318"
```

#### Option C: Use Localhost (when Agent uses hostNetwork)

If the Agent is configured with `hostNetwork: true`, applications can use:

```
localhost:4317  # for gRPC
localhost:4318  # for HTTP
```

### Python Example

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Configure resource attributes
resource = Resource.create({
    "service.name": "my-python-app",
    "service.version": "1.0.0",
    "resource.opentelemetry.io/env": "production",
    "resource.opentelemetry.io/team": "platform"
})

# Set up tracing
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces"
)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Auto-instrument HTTP requests
RequestsInstrumentor().instrument()

# Use in your code
def handle_request():
    with tracer.start_as_current_span("handle_request") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.url", "/api/users")
        # Your business logic here
        return {"status": "ok"}
```

### Node.js Example

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');

// Configure resource attributes
const resource = Resource.default().merge(
  new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'my-node-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    'resource.opentelemetry.io/env': 'production',
    'resource.opentelemetry.io/team': 'platform',
  })
);

// Configure OTLP exporter
const exporter = new OTLPTraceExporter({
  url: 'http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces',
});

// Set up tracing
const provider = new NodeTracerProvider({
  resource: resource,
});
provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();

// Auto-instrument Express
const expressInstrumentation = new ExpressInstrumentation();
expressInstrumentation.setTracerProvider(provider);

// Use in your code
const express = require('express');
const app = express();
const tracer = provider.getTracer('my-node-app');

app.get('/api/users', (req, res) => {
  const span = tracer.startSpan('handle_request');
  span.setAttributes({
    'http.method': 'GET',
    'http.url': '/api/users',
  });
  // Your business logic
  span.end();
  res.json({ status: 'ok' });
});
```

### Java Example

```java
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.exporter.otlp.http.trace.OtlpHttpSpanExporter;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.semconv.resource.attributes.ResourceAttributes;

public class TracingConfig {
    public static OpenTelemetry initializeOpenTelemetry() {
        Resource resource = Resource.getDefault()
            .merge(Resource.builder()
                .put(ResourceAttributes.SERVICE_NAME, "my-java-app")
                .put(ResourceAttributes.SERVICE_VERSION, "1.0.0")
                .put("resource.opentelemetry.io/env", "production")
                .put("resource.opentelemetry.io/team", "platform")
                .build());

        OtlpHttpSpanExporter spanExporter = OtlpHttpSpanExporter.builder()
            .setEndpoint("http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces")
            .build();

        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
            .addSpanProcessor(BatchSpanProcessor.builder(spanExporter).build())
            .setResource(resource)
            .build();

        return OpenTelemetrySdk.builder()
            .setTracerProvider(tracerProvider)
            .build();
    }

    public static void main(String[] args) {
        OpenTelemetry openTelemetry = initializeOpenTelemetry();
        Tracer tracer = openTelemetry.getTracer("my-java-app");

        // Use in your code
        var span = tracer.spanBuilder("handle_request")
            .setAttribute("http.method", "GET")
            .setAttribute("http.url", "/api/users")
            .startSpan();
        try {
            // Your business logic
        } finally {
            span.end();
        }
    }
}
```

### Go Example

```go
package main

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.12.0"
    "go.opentelemetry.io/otel/trace"
)

func initTracer() (*sdktrace.TracerProvider, error) {
    // Configure OTLP exporter
    exporter, err := otlptracehttp.New(
        context.Background(),
        otlptracehttp.WithEndpoint("my-otel-stack-agent.observability.svc.cluster.local:4318"),
        otlptracehttp.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    // Configure resource attributes
    res, err := resource.New(
        context.Background(),
        resource.WithAttributes(
            semconv.ServiceNameKey.String("my-go-app"),
            semconv.ServiceVersionKey.String("1.0.0"),
            resource.String("resource.opentelemetry.io/env", "production"),
            resource.String("resource.opentelemetry.io/team", "platform"),
        ),
    )
    if err != nil {
        return nil, err
    }

    // Create tracer provider
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
    )

    otel.SetTracerProvider(tp)
    return tp, nil
}

func main() {
    tp, err := initTracer()
    if err != nil {
        panic(err)
    }
    defer tp.Shutdown(context.Background())

    tracer := otel.Tracer("my-go-app")
    ctx, span := tracer.Start(context.Background(), "handle_request")
    defer span.End()

    span.SetAttributes(
        attribute.String("http.method", "GET"),
        attribute.String("http.url", "/api/users"),
    )

    // Your business logic
}
```

## Resource Attributes and Label Mapping

Resource attributes provide context about your services. The chart automatically maps certain labels:

### Default Label Mapping

The chart maps these standard OpenTelemetry resource attributes to Tsuga:

| OpenTelemetry Attribute | Tsuga Attribute |
|-------------------------|------------------|
| `resource.opentelemetry.io/service.name` | `context.service.name` |
| `resource.opentelemetry.io/service.version` | `context.service.version` |
| `resource.opentelemetry.io/env` | `context.env` |
| `resource.opentelemetry.io/team` | `context.team` |

### Setting Resource Attributes

In your application code, always set these attributes:

```python
# Python
resource = Resource.create({
    "service.name": "my-service",
    "service.version": "1.2.3",
    "resource.opentelemetry.io/env": "production",
    "resource.opentelemetry.io/team": "platform-team"
})
```

```javascript
// Node.js
const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: 'my-service',
  [SemanticResourceAttributes.SERVICE_VERSION]: '1.2.3',
  'resource.opentelemetry.io/env': 'production',
  'resource.opentelemetry.io/team': 'platform-team',
});
```

### Custom Label Mapping

You can configure additional label mappings in your Helm values:

```yaml
labelMapping:
  - tag_name: owner
    key: app.kubernetes.io/owner
    from: pod
  - tag_name: tier
    key: app.kubernetes.io/tier
    from: pod
```

This extracts pod labels and adds them as resource attributes.

## Environment Variables for Instrumentation

You can configure instrumentation via environment variables:

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "my-service"
  - name: OTEL_SERVICE_VERSION
    value: "1.0.0"
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://my-otel-stack-agent.observability.svc.cluster.local:4318"
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.name=my-service,service.version=1.0.0,resource.opentelemetry.io/env=production"
```

## Verifying Instrumentation

### Check if Traces are Being Sent

```bash
# View agent logs to see incoming traces
kubectl logs -n observability \
  -l app.kubernetes.io/component=agent \
  --tail=100 | grep -i trace

# Check cluster receiver logs for exported traces
kubectl logs -n observability \
  -l app.kubernetes.io/component=cluster-receiver \
  --tail=100 | grep -i trace
```

### Test with a Simple Application

Create a test pod that sends telemetry:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-instrumentation
spec:
  containers:
  - name: test
    image: curlimages/curl:latest
    command: ["/bin/sh", "-c", "sleep 3600"]
    env:
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://my-otel-stack-agent.observability.svc.cluster.local:4318"
```

## Best Practices

1. **Always Set Resource Attributes**: Service name, version, environment, team
2. **Use Batch Exporters**: More efficient than individual exports
3. **Set Appropriate Sampling**: Don't trace everything in production
4. **Use Semantic Conventions**: Standard attribute names for consistency
5. **Handle Errors Gracefully**: Instrumentation failures shouldn't break your app
6. **Use Auto-instrumentation When Possible**: Faster to implement
7. **Monitor Instrumentation Overhead**: Check resource usage

## Troubleshooting

### Traces Not Appearing

1. **Check Endpoint Configuration**:
   ```bash
   # Verify service exists
   kubectl get svc -n observability | grep agent
   ```

2. **Test Connectivity**:
   ```bash
   # From application pod
   curl -v http://my-otel-stack-agent.observability.svc.cluster.local:4318
   ```

3. **Check Agent Logs**:
   ```bash
   kubectl logs -n observability -l app.kubernetes.io/component=agent
   ```

### Authentication Issues

The Agent forwards to Cluster Receiver which uses Tsuga credentials. Verify:
- Secret exists with correct credentials
- Cluster Receiver can reach Tsuga endpoint
- API key is valid

## Next Steps

- **Customize Configuration**: See [Configuration Examples](04-configuration-examples.md)
- **Troubleshoot Issues**: See [Troubleshooting Guide](05-troubleshooting.md)
- **Advanced Topics**: See [Advanced Topics Guide](06-advanced-topics.md)

---

**Your applications are now sending telemetry!** The data flows: Application → Agent → Cluster Receiver → Tsuga.

