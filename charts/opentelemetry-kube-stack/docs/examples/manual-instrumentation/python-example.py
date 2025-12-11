"""
Python Manual Instrumentation Example
This example shows how to manually instrument a Python application
to send traces, metrics, and logs to OpenTelemetry collectors.
"""

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from flask import Flask, jsonify
import os

# Configure resource attributes
# These will be mapped to Tsuga context attributes
resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "my-python-app"),
    "service.version": os.getenv("OTEL_SERVICE_VERSION", "1.0.0"),
    "resource.opentelemetry.io/env": os.getenv("ENVIRONMENT", "production"),
    "resource.opentelemetry.io/team": os.getenv("TEAM", "platform"),
})

# Set up tracing
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter
# Point to the agent service in your cluster
otlp_endpoint = os.getenv(
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces"
)

otlp_exporter = OTLPSpanExporter(endpoint=otlp_endpoint)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Auto-instrument HTTP requests
RequestsInstrumentor().instrument()

# Example Flask application
app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)


@app.route("/")
def home():
    """Example endpoint with manual instrumentation."""
    with tracer.start_as_current_span("home_handler") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/")
        span.set_attribute("http.url", "/")
        
        # Your business logic here
        result = {"status": "ok", "message": "Hello from instrumented app"}
        
        span.set_attribute("http.status_code", 200)
        return jsonify(result)


@app.route("/api/users/<user_id>")
def get_user(user_id):
    """Example endpoint showing nested spans."""
    with tracer.start_as_current_span("get_user") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/users/<user_id>")
        span.set_attribute("user.id", user_id)
        
        # Simulate database call with child span
        with tracer.start_as_current_span("database_query") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.operation", "SELECT")
            db_span.set_attribute("db.sql.table", "users")
            
            # Simulate database work
            user_data = {"id": user_id, "name": "John Doe"}
            db_span.set_attribute("db.rows_affected", 1)
        
        span.set_attribute("http.status_code", 200)
        return jsonify(user_data)


@app.route("/api/health")
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)


# Environment variables for configuration:
# OTEL_SERVICE_NAME=my-python-app
# OTEL_SERVICE_VERSION=1.0.0
# OTEL_EXPORTER_OTLP_ENDPOINT=http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces
# ENVIRONMENT=production
# TEAM=platform

