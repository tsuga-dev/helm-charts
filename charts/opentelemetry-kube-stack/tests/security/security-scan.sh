#!/bin/bash
# Security scanning script for Helm chart

set -e

CHART_PATH="."
NAMESPACE="otel-security-test-$(date +%s)"
RELEASE_NAME="otel-security-test"

echo "Starting security scanning for OpenTelemetry Helm chart"
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

# Deploy chart for security scanning
helm install "$RELEASE_NAME" "$CHART_PATH" \
    -n "$NAMESPACE" \
    --set tsuga.otlpEndpoint="https://test-endpoint.com" \
    --set tsuga.apiKey="test-api-key" \
    --wait --timeout=300s

# Get rendered manifests
helm template "$RELEASE_NAME" "$CHART_PATH" \
    --set tsuga.otlpEndpoint="https://test-endpoint.com" \
    --set tsuga.apiKey="test-api-key" > /tmp/otel-manifests.yaml

echo "Running security scans..."

# Check if kube-score is available
if command -v kube-score &> /dev/null; then
    echo "Running kube-score security scan..."
    kube-score score /tmp/otel-manifests.yaml || true
else
    echo "kube-score not found, skipping kube-score scan"
    echo "Install with: go install github.com/zegl/kube-score/cmd/kube-score@latest"
fi

# Check if kubeaudit is available
if command -v kubeaudit &> /dev/null; then
    echo "Running kubeaudit security scan..."
    kubeaudit all -f /tmp/otel-manifests.yaml || true
else
    echo "kubeaudit not found, skipping kubeaudit scan"
    echo "Install with: go install github.com/Shopify/kubeaudit/cmd/kubeaudit@latest"
fi

# Check if polaris is available
if command -v polaris &> /dev/null; then
    echo "Running polaris security scan..."
    polaris audit --audit-path /tmp/otel-manifests.yaml || true
else
    echo "polaris not found, skipping polaris scan"
    echo "Install with: go install github.com/FairwindsOps/polaris/cmd/polaris@latest"
fi

# Basic security checks
echo "Running basic security checks..."

# Check for hardcoded secrets
if grep -i "password\|secret\|key" /tmp/otel-manifests.yaml | grep -v "TSUGA_API_KEY\|TSUGA_OTLP_ENDPOINT"; then
    echo "WARNING: Potential hardcoded secrets found"
fi

# Check for privileged containers
if kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].securityContext.privileged}' | grep -q true; then
    echo "WARNING: Privileged containers detected"
fi

# Check for host network usage
if kubectl get daemonset -n "$NAMESPACE" -o jsonpath='{.items[*].spec.template.spec.hostNetwork}' | grep -q true; then
    echo "INFO: Host network is enabled for daemonset (expected for OpenTelemetry agent)"
fi

# Check for security contexts
echo "Checking security contexts..."
kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].securityContext}' | jq . || echo "No security contexts found"

# Check for resource limits
echo "Checking resource limits..."
kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].resources}' | jq . || echo "No resource limits found"

# Check for RBAC permissions
echo "Checking RBAC permissions..."
kubectl get clusterrole opentelemetry-kube-stack -o yaml | grep -A 20 "rules:" || echo "RBAC rules not found"

echo "Security scanning completed!"
