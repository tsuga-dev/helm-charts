# OpenTelemetry Helm Chart Testing

This directory contains comprehensive testing for the OpenTelemetry Helm chart, including unit tests, integration tests, security scans, and CI/CD pipeline configuration.

## Testing Framework Overview

### 1. Unit Tests (Helm Unittest)

Located in `tests/` directory, these tests validate individual template rendering:

- **secret_test.yaml** - Tests secret creation and configuration
- **serviceaccount_test.yaml** - Tests service account creation
- **rbac_test.yaml** - Tests RBAC resources and permissions
- **daemonset_test.yaml** - Tests agent daemonset configuration
- **cluster-receiver_test.yaml** - Tests cluster receiver deployment
- **instrumentation_test.yaml** - Tests auto-instrumentation resource creation and configuration

#### Running Unit Tests

```bash
# Install helm unittest plugin
helm plugin install https://github.com/quintush/helm-unittest

# Run all unit tests
helm unittest charts/opentelemetry-kube-stack

# Run specific test file
helm unittest charts/opentelemetry-kube-stack -f tests/secret_test.yaml
```

### 2. Integration Tests

Located in `tests/integration/`, these tests validate end-to-end deployment scenarios:

- **test-deployment.sh** - Tests chart installation, upgrade, rollback, and cleanup
- **test-auto-instrumentation.sh** - Tests auto-instrumentation functionality with the OpenTelemetry Operator

#### Running Integration Tests

```bash
# Prerequisites: kubectl and helm configured with a test cluster
cd charts/opentelemetry-kube-stack
./tests/integration/test-deployment.sh
```

### 3. Security Scanning

Located in `tests/security/`, these tests validate security best practices:

- **security-scan.sh** - Runs kube-score, kubeaudit, and polaris security scans

#### Running Security Tests

```bash
# Install security scanning tools
go install github.com/zegl/kube-score/cmd/kube-score@latest
go install github.com/Shopify/kubeaudit/cmd/kubeaudit@latest
go install github.com/FairwindsOps/polaris/cmd/polaris@latest

# Run security scans
cd charts/opentelemetry-kube-stack
./tests/security/security-scan.sh
```

### 4. Test Values Files

Located in `tests/values/`, these files provide different configuration scenarios:

- **minimal.yaml** - Minimal required configuration
- **agent-only.yaml** - Agent-only deployment
- **cluster-only.yaml** - Cluster receiver only
- **existing-secret.yaml** - Using existing Kubernetes secret
- **production.yaml** - Production-ready configuration
- **auto-instrumentation.yaml** - Auto-instrumentation with all language support enabled

#### Using Test Values

```bash
# Test with specific values file
helm install my-release ./charts/opentelemetry-kube-stack \
  -f tests/values/production.yaml \
  --set tsuga.otlpEndpoint="https://your-endpoint.com" \
  --set tsuga.apiKey="your-api-key"
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/test.yml`) includes:

1. **Lint** - Helm chart linting
2. **Unit Tests** - Helm unittest execution
3. **Security Scan** - Security scanning with multiple tools
4. **Integration Test** - End-to-end deployment testing
5. **Chart Test** - Helm chart-testing framework

### Pipeline Stages

```yaml
lint → unittest → security-scan
                ↓
         integration-test ← chart-test
```

## Testing Best Practices

### 1. Unit Test Guidelines

- Test all template conditions and branches
- Validate resource metadata and labels
- Test with different value combinations
- Include negative test cases (when resources should not be created)

### 2. Integration Test Guidelines

- Test complete deployment lifecycle
- Validate resource creation and functionality
- Test upgrade and rollback scenarios
- Clean up test resources properly

### 3. Security Test Guidelines

- Scan for hardcoded secrets
- Validate RBAC permissions
- Check for privileged containers
- Verify resource limits and security contexts

### 4. Test Data Management

- Use test-specific values (never production secrets)
- Use unique namespaces for each test run
- Implement proper cleanup procedures
- Use time-based naming to avoid conflicts

## Running All Tests

```bash
# Run complete test suite
cd charts/opentelemetry-kube-stack

# 1. Unit tests
helm unittest .

# 2. Integration tests (requires kubectl access)
./tests/integration/test-deployment.sh

# 3. Auto-instrumentation tests (requires OpenTelemetry Operator)
./tests/integration/test-auto-instrumentation.sh

# 4. Security scans
./tests/security/security-scan.sh

# 5. Manual chart testing
helm lint .
helm template . --set tsuga.otlpEndpoint="https://test.com" --set tsuga.apiKey="test-key"
```

## Auto-Instrumentation Testing

For detailed information about testing the auto-instrumentation feature, see [AUTO_INSTRUMENTATION_TESTING.md](AUTO_INSTRUMENTATION_TESTING.md).

This includes:
- Comprehensive unit tests for the Instrumentation resource
- Integration tests that validate auto-instrumentation injection
- Example applications demonstrating usage
- Troubleshooting guides

## Troubleshooting

### Common Issues

1. **Unit test failures**: Check template syntax and test assertions
2. **Integration test timeouts**: Increase timeout values for slow clusters
3. **Security scan warnings**: Review and address security recommendations
4. **Resource conflicts**: Ensure unique namespaces and resource names

### Debug Commands

```bash
# Debug template rendering
helm template . --debug --set tsuga.otlpEndpoint="https://test.com" --set tsuga.apiKey="test-key"

# Check resource status
kubectl get all -n <namespace>

# View logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-kube-stack
```

## Contributing

When adding new tests:

1. Follow existing naming conventions
2. Include both positive and negative test cases
3. Update documentation
4. Ensure tests are idempotent
5. Add appropriate cleanup procedures

## Security Considerations

- Never commit real API keys or endpoints
- Use test-specific values in all test files
- Implement proper secret management in CI/CD
- Regularly update security scanning tools
- Review and address security scan results

## References

- [OpenTelemetry Operator Documentation](https://github.com/open-telemetry/opentelemetry-operator)
- [Instrumentation API Reference](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#instrumentation)
- [Auto-Instrumentation Annotations](https://github.com/open-telemetry/opentelemetry-operator#opentelemetry-auto-instrumentation-injection)
- [Helm Unittest Plugin](https://github.com/quintush/helm-unittest)
