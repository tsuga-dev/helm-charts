/**
 * Node.js Manual Instrumentation Example
 * This example shows how to manually instrument a Node.js application
 * to send traces, metrics, and logs to OpenTelemetry collectors.
 */

const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');

const express = require('express');

// Configure resource attributes
// These will be mapped to Tsuga context attributes
const resource = Resource.default().merge(
  new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'my-node-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.OTEL_SERVICE_VERSION || '1.0.0',
    'resource.opentelemetry.io/env': process.env.ENVIRONMENT || 'production',
    'resource.opentelemetry.io/team': process.env.TEAM || 'platform',
  })
);

// Configure OTLP exporter
// Point to the agent service in your cluster
const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 
  'http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces';

const exporter = new OTLPTraceExporter({
  url: otlpEndpoint,
});

// Set up tracing
const provider = new NodeTracerProvider({
  resource: resource,
});

provider.addSpanProcessor(new BatchSpanProcessor(exporter));
provider.register();

// Register auto-instrumentations
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
});

const tracer = provider.getTracer('my-node-app');
const app = express();
app.use(express.json());

// Example endpoint with manual instrumentation
app.get('/', (req, res) => {
  const span = tracer.startSpan('home_handler');
  span.setAttributes({
    'http.method': 'GET',
    'http.route': '/',
    'http.url': '/',
  });
  
  try {
    // Your business logic here
    const result = { status: 'ok', message: 'Hello from instrumented app' };
    
    span.setAttribute('http.status_code', 200);
    span.end();
    res.json(result);
  } catch (error) {
    span.recordException(error);
    span.setAttribute('http.status_code', 500);
    span.end();
    res.status(500).json({ error: error.message });
  }
});

// Example endpoint with nested spans
app.get('/api/users/:userId', async (req, res) => {
  const span = tracer.startSpan('get_user');
  span.setAttributes({
    'http.method': 'GET',
    'http.route': '/api/users/:userId',
    'user.id': req.params.userId,
  });
  
  try {
    // Simulate database call with child span
    const dbSpan = tracer.startSpan('database_query', {
      parent: span,
    });
    dbSpan.setAttributes({
      'db.system': 'postgresql',
      'db.operation': 'SELECT',
      'db.sql.table': 'users',
    });
    
    // Simulate database work
    await new Promise(resolve => setTimeout(resolve, 50));
    const userData = { id: req.params.userId, name: 'John Doe' };
    
    dbSpan.setAttribute('db.rows_affected', 1);
    dbSpan.end();
    
    span.setAttribute('http.status_code', 200);
    span.end();
    res.json(userData);
  } catch (error) {
    span.recordException(error);
    span.setAttribute('http.status_code', 500);
    span.end();
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy' });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Environment variables for configuration:
// OTEL_SERVICE_NAME=my-node-app
// OTEL_SERVICE_VERSION=1.0.0
// OTEL_EXPORTER_OTLP_ENDPOINT=http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces
// ENVIRONMENT=production
// TEAM=platform

