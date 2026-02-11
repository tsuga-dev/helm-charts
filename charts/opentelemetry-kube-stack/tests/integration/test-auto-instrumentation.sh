#!/bin/bash
# Integration test for OpenTelemetry auto-instrumentation
# This script tests that auto-instrumentation works correctly with the OpenTelemetry Operator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAMESPACE="otel-autoinstr-test-$(date +%s)"
RELEASE_NAME="otel-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up test resources..."
    kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true --wait=false 2>/dev/null || true
    print_success "Cleanup completed"
}

# Set up cleanup trap
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install Helm."
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please configure kubectl."
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

# Check if OpenTelemetry Operator is installed
check_operator() {
    print_status "Checking if OpenTelemetry Operator is installed..."
    
    if ! kubectl get crd instrumentations.opentelemetry.io &> /dev/null; then
        print_warning "OpenTelemetry Operator is not installed."
        print_status "Installing OpenTelemetry Operator..."
        
        # Add OpenTelemetry Operator Helm repository
        helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
        helm repo update
        
        # Install the operator
        kubectl create namespace opentelemetry-operator-system --dry-run=client -o yaml | kubectl apply -f -
        helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
            --namespace opentelemetry-operator-system \
            --wait \
            --timeout 5m
        
        print_success "OpenTelemetry Operator installed"
    else
        print_success "OpenTelemetry Operator is already installed"
    fi
}

# Create test namespace
create_namespace() {
    print_status "Creating test namespace: $TEST_NAMESPACE"
    kubectl create namespace "$TEST_NAMESPACE"
    print_success "Namespace created"
}

# Install the chart with auto-instrumentation enabled
install_chart() {
    print_status "Installing chart with auto-instrumentation enabled..."
    
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$TEST_NAMESPACE" \
        --set autoInstrumentation.enabled=true \
        --set autoInstrumentation.spec.exporter.endpoint="http://localhost:4317" \
        --set autoInstrumentation.spec.propagators[0]=tracecontext \
        --set autoInstrumentation.spec.propagators[1]=baggage \
        --set autoInstrumentation.spec.java.image="ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest" \
        --set autoInstrumentation.spec.nodejs.image="ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest" \
        --set autoInstrumentation.spec.python.image="ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest" \
        --set tsuga.otlpEndpoint="https://test-endpoint.example.com" \
        --set tsuga.apiKey="test-api-key-12345" \
        --wait \
        --timeout 5m
    
    print_success "Chart installed successfully"
}

# Verify Instrumentation resource was created
verify_instrumentation_resource() {
    print_status "Verifying Instrumentation resource was created..."
    
    local instrumentation_name="${RELEASE_NAME}-opentelemetry-kube-stack-instrumentation"
    
    if ! kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" &> /dev/null; then
        print_error "Instrumentation resource not found"
        return 1
    fi
    
    print_success "Instrumentation resource found: $instrumentation_name"
    
    # Display the instrumentation resource
    print_status "Instrumentation resource details:"
    kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o yaml
}

# Verify instrumentation configuration
verify_instrumentation_config() {
    print_status "Verifying Instrumentation configuration..."
    
    local instrumentation_name="${RELEASE_NAME}-opentelemetry-kube-stack-instrumentation"
    
    # Check exporter endpoint
    local endpoint=$(kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.exporter.endpoint}')
    if [ "$endpoint" != "http://localhost:4317" ]; then
        print_error "Exporter endpoint mismatch. Expected: http://localhost:4317, Got: $endpoint"
        return 1
    fi
    print_success "Exporter endpoint is correct"
    
    # Check propagators
    local propagators=$(kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.propagators}')
    if [[ ! "$propagators" =~ "tracecontext" ]] || [[ ! "$propagators" =~ "baggage" ]]; then
        print_error "Propagators configuration incorrect. Got: $propagators"
        return 1
    fi
    print_success "Propagators are correct"
    
    # Check Java instrumentation image
    local java_image=$(kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.java.image}')
    if [ -z "$java_image" ]; then
        print_error "Java instrumentation image not configured"
        return 1
    fi
    print_success "Java instrumentation image is configured: $java_image"
    
    # Check Node.js instrumentation image
    local nodejs_image=$(kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.nodejs.image}')
    if [ -z "$nodejs_image" ]; then
        print_error "Node.js instrumentation image not configured"
        return 1
    fi
    print_success "Node.js instrumentation image is configured: $nodejs_image"
    
    # Check Python instrumentation image
    local python_image=$(kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.python.image}')
    if [ -z "$python_image" ]; then
        print_error "Python instrumentation image not configured"
        return 1
    fi
    print_success "Python instrumentation image is configured: $python_image"
}

# Deploy a test application with auto-instrumentation annotation
deploy_test_app() {
    print_status "Deploying test application with auto-instrumentation..."
    
    local instrumentation_name="${RELEASE_NAME}-opentelemetry-kube-stack-instrumentation"
    
    cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-java-app
  labels:
    app: test-java-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-java-app
  template:
    metadata:
      labels:
        app: test-java-app
      annotations:
        instrumentation.opentelemetry.io/inject-java: "${TEST_NAMESPACE}/${instrumentation_name}"
    spec:
      containers:
      - name: app
        image: openjdk:11-jre-slim
        command: ["sh", "-c", "while true; do echo 'Running...'; sleep 10; done"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-nodejs-app
  labels:
    app: test-nodejs-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-nodejs-app
  template:
    metadata:
      labels:
        app: test-nodejs-app
      annotations:
        instrumentation.opentelemetry.io/inject-nodejs: "${TEST_NAMESPACE}/${instrumentation_name}"
    spec:
      containers:
      - name: app
        image: node:16-alpine
        command: ["sh", "-c", "while true; do echo 'Running...'; sleep 10; done"]
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
EOF
    
    print_success "Test applications deployed"
    
    # Wait for deployments to be ready
    print_status "Waiting for test applications to be ready..."
    kubectl wait --for=condition=available --timeout=180s deployment/test-java-app -n "$TEST_NAMESPACE" || true
    kubectl wait --for=condition=available --timeout=180s deployment/test-nodejs-app -n "$TEST_NAMESPACE" || true
}

# Verify auto-instrumentation was injected
verify_instrumentation_injection() {
    print_status "Verifying auto-instrumentation was injected..."
    
    # Check Java app
    print_status "Checking Java application..."
    local java_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=test-java-app -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$java_pod" ]; then
        print_warning "Java pod not found yet"
    else
        # Check if init container was injected
        local init_containers=$(kubectl get pod "$java_pod" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.initContainers[*].name}')
        if [[ "$init_containers" =~ "opentelemetry-auto-instrumentation" ]]; then
            print_success "Java app: Auto-instrumentation init container injected"
        else
            print_warning "Java app: No auto-instrumentation init container found. Init containers: $init_containers"
        fi
        
        # Check if OTEL environment variables were injected
        local env_vars=$(kubectl get pod "$java_pod" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].env[*].name}')
        if [[ "$env_vars" =~ "OTEL" ]]; then
            print_success "Java app: OTEL environment variables injected"
        else
            print_warning "Java app: No OTEL environment variables found"
        fi
    fi
    
    # Check Node.js app
    print_status "Checking Node.js application..."
    local nodejs_pod=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=test-nodejs-app -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$nodejs_pod" ]; then
        print_warning "Node.js pod not found yet"
    else
        # Check if init container was injected
        local init_containers=$(kubectl get pod "$nodejs_pod" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.initContainers[*].name}')
        if [[ "$init_containers" =~ "opentelemetry-auto-instrumentation" ]]; then
            print_success "Node.js app: Auto-instrumentation init container injected"
        else
            print_warning "Node.js app: No auto-instrumentation init container found. Init containers: $init_containers"
        fi
        
        # Check if OTEL environment variables were injected
        local env_vars=$(kubectl get pod "$nodejs_pod" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.containers[0].env[*].name}')
        if [[ "$env_vars" =~ "OTEL" ]]; then
            print_success "Node.js app: OTEL environment variables injected"
        else
            print_warning "Node.js app: No OTEL environment variables found"
        fi
    fi
}

# Test chart upgrade with modified instrumentation config
test_chart_upgrade() {
    print_status "Testing chart upgrade with modified instrumentation config..."
    
    helm upgrade "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$TEST_NAMESPACE" \
        --set autoInstrumentation.enabled=true \
        --set autoInstrumentation.spec.exporter.endpoint="http://modified-endpoint:4317" \
        --set autoInstrumentation.spec.propagators[0]=tracecontext \
        --set autoInstrumentation.spec.java.image="ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest" \
        --set autoInstrumentation.labels.environment=test \
        --set tsuga.otlpEndpoint="https://test-endpoint.example.com" \
        --set tsuga.apiKey="test-api-key-12345" \
        --wait \
        --timeout 5m
    
    print_success "Chart upgraded successfully"
    
    # Verify the update
    local instrumentation_name="${RELEASE_NAME}-opentelemetry-kube-stack-instrumentation"
    local endpoint=$(kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o jsonpath='{.spec.exporter.endpoint}')
    if [ "$endpoint" = "http://modified-endpoint:4317" ]; then
        print_success "Instrumentation configuration updated correctly"
    else
        print_error "Instrumentation configuration not updated. Expected: http://modified-endpoint:4317, Got: $endpoint"
        return 1
    fi
    
    local env_label=$(kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" -o jsonpath='{.metadata.labels.environment}')
    if [ "$env_label" = "test" ]; then
        print_success "Instrumentation labels updated correctly"
    else
        print_error "Instrumentation labels not updated. Expected: test, Got: $env_label"
        return 1
    fi
}

# Test disabling auto-instrumentation
test_disable_instrumentation() {
    print_status "Testing disabling auto-instrumentation..."
    
    helm upgrade "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$TEST_NAMESPACE" \
        --set autoInstrumentation.enabled=false \
        --set tsuga.otlpEndpoint="https://test-endpoint.example.com" \
        --set tsuga.apiKey="test-api-key-12345" \
        --wait \
        --timeout 5m
    
    print_success "Chart upgraded with auto-instrumentation disabled"
    
    # Verify the Instrumentation resource is gone
    local instrumentation_name="${RELEASE_NAME}-opentelemetry-kube-stack-instrumentation"
    if kubectl get instrumentation "$instrumentation_name" -n "$TEST_NAMESPACE" &> /dev/null; then
        print_error "Instrumentation resource still exists after disabling"
        return 1
    fi
    
    print_success "Instrumentation resource removed successfully"
}

# Main test execution
main() {
    print_status "Starting auto-instrumentation integration tests..."
    echo "Test namespace: $TEST_NAMESPACE"
    echo "Release name: $RELEASE_NAME"
    echo ""
    
    check_prerequisites
    check_operator
    create_namespace
    install_chart
    
    # Run verification tests
    verify_instrumentation_resource
    verify_instrumentation_config
    deploy_test_app
    
    # Wait a bit for operator to process
    print_status "Waiting for operator to process annotations..."
    sleep 10
    
    verify_instrumentation_injection
    
    # Test upgrade scenarios
    test_chart_upgrade
    test_disable_instrumentation
    
    print_success "All auto-instrumentation integration tests passed! 🎉"
}

# Run main function
main
