// Go Manual Instrumentation Example
// This example shows how to manually instrument a Go application
// to send traces, metrics, and logs to OpenTelemetry collectors.
//
// Dependencies:
//   go get go.opentelemetry.io/otel
//   go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp
//   go get go.opentelemetry.io/otel/sdk/resource
//   go get go.opentelemetry.io/otel/sdk/trace
//   go get go.opentelemetry.io/otel/semconv/v1.12.0

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.12.0"
	"go.opentelemetry.io/otel/trace"
)

var tracer trace.Tracer

func initTracer() (*sdktrace.TracerProvider, error) {
	// Get OTLP endpoint from environment
	otlpEndpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if otlpEndpoint == "" {
		otlpEndpoint = "my-otel-stack-agent.observability.svc.cluster.local:4318"
	}

	// Configure OTLP exporter
	exporter, err := otlptracehttp.New(
		context.Background(),
		otlptracehttp.WithEndpoint(otlpEndpoint),
		otlptracehttp.WithInsecure(), // Use WithTLSClientConfig for production
		otlptracehttp.WithURLPath("/v1/traces"),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create OTLP exporter: %w", err)
	}

	// Configure resource attributes
	// These will be mapped to Tsuga context attributes
	serviceName := os.Getenv("OTEL_SERVICE_NAME")
	if serviceName == "" {
		serviceName = "my-go-app"
	}
	serviceVersion := os.Getenv("OTEL_SERVICE_VERSION")
	if serviceVersion == "" {
		serviceVersion = "1.0.0"
	}
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "production"
	}
	team := os.Getenv("TEAM")
	if team == "" {
		team = "platform"
	}

	res, err := resource.New(
		context.Background(),
		resource.WithAttributes(
			semconv.ServiceNameKey.String(serviceName),
			semconv.ServiceVersionKey.String(serviceVersion),
			attribute.String("resource.opentelemetry.io/env", environment),
			attribute.String("resource.opentelemetry.io/team", team),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// Create tracer provider
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()), // Adjust for production
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	tracer = tp.Tracer("my-go-app")
	return tp, nil
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "home_handler")
	defer span.End()

	span.SetAttributes(
		attribute.String("http.method", r.Method),
		attribute.String("http.route", "/"),
		attribute.String("http.url", r.URL.Path),
	)

	// Your business logic here
	result := map[string]string{
		"status":  "ok",
		"message": "Hello from instrumented app",
	}

	span.SetAttributes(attribute.Int("http.status_code", 200))
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"ok","message":"Hello from instrumented app"}`)
}

func handleGetUser(w http.ResponseWriter, r *http.Request, userID string) {
	ctx, span := tracer.Start(r.Context(), "get_user")
	defer span.End()

	span.SetAttributes(
		attribute.String("http.method", r.Method),
		attribute.String("http.route", "/api/users/:userId"),
		attribute.String("user.id", userID),
	)

	// Simulate database call with child span
	_, dbSpan := tracer.Start(ctx, "database_query")
	dbSpan.SetAttributes(
		attribute.String("db.system", "postgresql"),
		attribute.String("db.operation", "SELECT"),
		attribute.String("db.sql.table", "users"),
	)

	// Simulate database work
	time.Sleep(50 * time.Millisecond)
	userData := map[string]interface{}{
		"id":   userID,
		"name": "John Doe",
	}

	dbSpan.SetAttributes(attribute.Int("db.rows_affected", 1))
	dbSpan.End()

	span.SetAttributes(attribute.Int("http.status_code", 200))
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"id":"%s","name":"John Doe"}`, userID)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"healthy"}`)
}

func main() {
	// Initialize tracing
	tp, err := initTracer()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize tracer: %v\n", err)
		os.Exit(1)
	}
	defer func() {
		if err := tp.Shutdown(context.Background()); err != nil {
			fmt.Fprintf(os.Stderr, "Error shutting down tracer: %v\n", err)
		}
	}()

	// Set up HTTP routes
	http.HandleFunc("/", handleHome)
	http.HandleFunc("/api/users/", func(w http.ResponseWriter, r *http.Request) {
		userID := r.URL.Path[len("/api/users/"):]
		handleGetUser(w, r, userID)
	})
	http.HandleFunc("/api/health", handleHealth)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	fmt.Printf("Server running on port %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		fmt.Fprintf(os.Stderr, "Server failed: %v\n", err)
		os.Exit(1)
	}
}

// Environment variables for configuration:
// OTEL_SERVICE_NAME=my-go-app
// OTEL_SERVICE_VERSION=1.0.0
// OTEL_EXPORTER_OTLP_ENDPOINT=my-otel-stack-agent.observability.svc.cluster.local:4318
// ENVIRONMENT=production
// TEAM=platform

