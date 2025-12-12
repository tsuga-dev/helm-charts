# OpenTelemetry Helm Chart Makefile

.PHONY: help lint unittest integration security clean install test-all docs

# Default target
help:
	@echo "Available targets:"
	@echo "  lint          - Lint the Helm chart"
	@echo "  unittest      - Run Helm unit tests"
	@echo "  integration   - Run integration tests"
	@echo "  security      - Run security scans"
	@echo "  test-all      - Run all tests"
	@echo "  clean         - Clean up test resources"
	@echo "  install       - Install chart with test values"
	@echo "  docs          - Generate documentation using helm-docs"

# Lint the Helm chart
lint:
	@echo "Linting Helm chart..."
	helm lint .

# Run Helm unit tests
unittest:
	@echo "Running Helm unit tests..."
	@if ! helm plugin list | grep -q unittest; then \
		echo "Installing helm unittest plugin..."; \
		helm plugin install https://github.com/quintush/helm-unittest; \
	fi
	helm unittest .

# Run integration tests
integration:
	@echo "Running integration tests..."
	@if ! command -v kubectl &> /dev/null; then \
		echo "kubectl not found. Please install kubectl and configure cluster access."; \
		exit 1; \
	fi
	chmod +x tests/integration/test-deployment.sh
	./tests/integration/test-deployment.sh

# Run security scans
security:
	@echo "Running security scans..."
	@if ! command -v kube-score &> /dev/null; then \
		echo "Installing kube-score..."; \
		go install github.com/zegl/kube-score/cmd/kube-score@latest; \
	fi
	@if ! command -v kubeaudit &> /dev/null; then \
		echo "Installing kubeaudit..."; \
		go install github.com/Shopify/kubeaudit/cmd/kubeaudit@latest; \
	fi
	@if ! command -v polaris &> /dev/null; then \
		echo "Installing polaris..."; \
		go install github.com/FairwindsOps/polaris/cmd/polaris@latest; \
	fi
	chmod +x tests/security/security-scan.sh
	./tests/security/security-scan.sh

# Run all tests
test-all: lint unittest security
	@echo "All tests completed!"

# Clean up test resources
clean:
	@echo "Cleaning up test resources..."
	@kubectl delete namespace otel-test-* --ignore-not-found=true || true
	@kubectl delete namespace otel-security-test-* --ignore-not-found=true || true
	@kubectl delete namespace otel-integration-test-* --ignore-not-found=true || true

# Install chart with test values
install:
	@echo "Installing chart with test values..."
	helm install otel-test . \
		--set tsuga.otlpEndpoint="https://test-endpoint.com" \
		--set tsuga.apiKey="test-api-key" \
		--wait --timeout=300s

# Uninstall test release
uninstall:
	@echo "Uninstalling test release..."
	helm uninstall otel-test --ignore-not-found=true

# Template the chart for inspection
template:
	@echo "Templating chart..."
	helm template otel-test . \
		--set tsuga.otlpEndpoint="https://test-endpoint.com" \
		--set tsuga.apiKey="test-api-key"

# Dry run installation
dry-run:
	@echo "Dry run installation..."
	helm install otel-test . \
		--set tsuga.otlpEndpoint="https://test-endpoint.com" \
		--set tsuga.apiKey="test-api-key" \
		--dry-run --debug

# Test with different value files
test-minimal:
	helm template otel-test . -f tests/values/minimal.yaml

test-agent-only:
	helm template otel-test . -f tests/values/agent-only.yaml

test-cluster-only:
	helm template otel-test . -f tests/values/cluster-only.yaml

test-existing-secret:
	helm template otel-test . -f tests/values/existing-secret.yaml

test-production:
	helm template otel-test . -f tests/values/production.yaml
