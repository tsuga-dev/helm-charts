/**
 * Java Manual Instrumentation Example
 * This example shows how to manually instrument a Java application
 * to send traces, metrics, and logs to OpenTelemetry collectors.
 * 
 * Dependencies (Maven):
 * <dependency>
 *   <groupId>io.opentelemetry</groupId>
 *   <artifactId>opentelemetry-api</artifactId>
 *   <version>1.30.0</version>
 * </dependency>
 * <dependency>
 *   <groupId>io.opentelemetry</groupId>
 *   <artifactId>opentelemetry-sdk</artifactId>
 *   <version>1.30.0</version>
 * </dependency>
 * <dependency>
 *   <groupId>io.opentelemetry</groupId>
 *   <artifactId>opentelemetry-exporter-otlp</artifactId>
 *   <version>1.30.0</version>
 * </dependency>
 */

package com.example.otel;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.exporter.otlp.http.trace.OtlpHttpSpanExporter;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.semconv.resource.attributes.ResourceAttributes;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.common.Attributes;

public class TracingConfig {
    private static Tracer tracer;

    public static OpenTelemetry initializeOpenTelemetry() {
        // Configure resource attributes
        // These will be mapped to Tsuga context attributes
        String serviceName = System.getenv().getOrDefault("OTEL_SERVICE_NAME", "my-java-app");
        String serviceVersion = System.getenv().getOrDefault("OTEL_SERVICE_VERSION", "1.0.0");
        String environment = System.getenv().getOrDefault("ENVIRONMENT", "production");
        String team = System.getenv().getOrDefault("TEAM", "platform");

        Resource resource = Resource.getDefault()
            .merge(Resource.builder()
                .put(ResourceAttributes.SERVICE_NAME, serviceName)
                .put(ResourceAttributes.SERVICE_VERSION, serviceVersion)
                .put("resource.opentelemetry.io/env", environment)
                .put("resource.opentelemetry.io/team", team)
                .build());

        // Configure OTLP exporter
        // Point to the agent service in your cluster
        String otlpEndpoint = System.getenv().getOrDefault(
            "OTEL_EXPORTER_OTLP_ENDPOINT",
            "http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces"
        );

        OtlpHttpSpanExporter spanExporter = OtlpHttpSpanExporter.builder()
            .setEndpoint(otlpEndpoint)
            .build();

        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
            .addSpanProcessor(BatchSpanProcessor.builder(spanExporter).build())
            .setResource(resource)
            .build();

        OpenTelemetry openTelemetry = OpenTelemetrySdk.builder()
            .setTracerProvider(tracerProvider)
            .build();

        tracer = openTelemetry.getTracer("my-java-app");
        
        return openTelemetry;
    }

    public static void main(String[] args) {
        OpenTelemetry openTelemetry = initializeOpenTelemetry();
        tracer = openTelemetry.getTracer("my-java-app");

        // Example: Create a span for a request handler
        Span span = tracer.spanBuilder("handle_request")
            .setSpanKind(SpanKind.SERVER)
            .setAttribute("http.method", "GET")
            .setAttribute("http.url", "/api/users")
            .startSpan();

        try {
            // Your business logic here
            processRequest(span);
            
            span.setAttribute("http.status_code", 200);
        } catch (Exception e) {
            span.recordException(e);
            span.setAttribute("http.status_code", 500);
        } finally {
            span.end();
        }
    }

    private static void processRequest(Span parentSpan) {
        // Create a child span for database operation
        Span dbSpan = tracer.spanBuilder("database_query")
            .setSpanKind(SpanKind.CLIENT)
            .setParent(io.opentelemetry.context.Context.current().with(parentSpan))
            .setAttribute("db.system", "postgresql")
            .setAttribute("db.operation", "SELECT")
            .setAttribute("db.sql.table", "users")
            .startSpan();

        try {
            // Simulate database work
            Thread.sleep(50);
            
            dbSpan.setAttribute("db.rows_affected", 1);
        } catch (InterruptedException e) {
            dbSpan.recordException(e);
            Thread.currentThread().interrupt();
        } finally {
            dbSpan.end();
        }
    }

    public static Tracer getTracer() {
        return tracer;
    }
}

// Environment variables for configuration:
// OTEL_SERVICE_NAME=my-java-app
// OTEL_SERVICE_VERSION=1.0.0
// OTEL_EXPORTER_OTLP_ENDPOINT=http://my-otel-stack-agent.observability.svc.cluster.local:4318/v1/traces
// ENVIRONMENT=production
// TEAM=platform

