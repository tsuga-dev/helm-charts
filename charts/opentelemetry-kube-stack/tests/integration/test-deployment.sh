#!/bin/bash
# Integration test script for Helm chart deployment

set -e

CHART_PATH="."
NAMESPACE="otel-test-$(date +%s)"
RELEASE_NAME="otel-integration-test"

echo "Starting integration tests for OpenTelemetry Helm chart"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"

# Cleanup function
cleanup() {
    echo "Cleaning up test resources..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
    kubectl delete namespace "$NAMESPACE" || true
}
trap cleanup EXIT

# Create test namespace
kubectl create namespace "$NAMESPACE"

# Test 1: Deploy with minimal configuration
echo "Test 1: Deploying with minimal configuration..."
helm install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" \
    --set tsuga.apiKey="<TSUGA_API_KEY>" \
    --wait --timeout=300s

# Verify resources are created
echo "Verifying resources..."
kubectl get secret -n "$NAMESPACE" | grep otel-secret
kubectl get serviceaccount -n "$NAMESPACE" | grep opentelemetry-kube-stack
kubectl get clusterrole | grep opentelemetry-kube-stack
kubectl get clusterrolebinding | grep opentelemetry-kube-stack
kubectl get daemonset -n "$NAMESPACE" | grep opentelemetry-kube-stack
kubectl get deployment -n "$NAMESPACE" | grep opentelemetry-kube-stack

# Test 2: Upgrade with different configuration
echo "Test 2: Testing upgrade..."
helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" \
    --set tsuga.apiKey="<TSUGA_API_KEY>" \
    --set resources.limits.memory="1Gi" \
    --wait --timeout=300s

# Test 3: Test rollback
echo "Test 3: Testing rollback..."
helm rollback "$RELEASE_NAME" -n "$NAMESPACE" --wait --timeout=300s

# Test 4: Test with existing secret
echo "Test 4: Testing with existing secret..."
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true

# Create existing secret
kubectl create secret generic existing-otel-secret \
    -n "$NAMESPACE" \
    --from-literal=tsuga-api-key="<TSUGA_API_KEY>" \
    --from-literal=tsuga-otlp-endpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp"

helm install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    --set secret.existing.enabled=true \
    --set secret.existing.name="existing-otel-secret" \
    --wait --timeout=300s

# Verify existing secret is used
SECRET_NAME=$(kubectl get secret -n "$NAMESPACE" -o name | grep otel-secret)
if [ -z "$SECRET_NAME" ]; then
    echo "ERROR: Secret not found"
    exit 1
fi

echo "All integration tests passed!"
