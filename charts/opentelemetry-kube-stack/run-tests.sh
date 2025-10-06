#!/bin/bash
# Test runner script for OpenTelemetry Helm chart

set -e

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CHART_DIR"

echo "🚀 Starting OpenTelemetry Helm Chart Test Suite"
echo "Chart directory: $CHART_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm not found. Please install Helm."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl not found. Integration tests will be skipped."
        SKIP_INTEGRATION=true
    fi
    
    print_success "Prerequisites check completed"
}

# Run linting
run_lint() {
    print_status "Running Helm lint..."
    if helm lint .; then
        print_success "Helm lint passed"
    else
        print_error "Helm lint failed"
        exit 1
    fi
}

# Run unit tests
run_unittest() {
    print_status "Running Helm unit tests..."
    
    # Install unittest plugin if not present
    if ! helm plugin list | grep -q unittest; then
        print_status "Installing helm unittest plugin..."
        helm plugin install https://github.com/quintush/helm-unittest
    fi
    
    if helm unittest .; then
        print_success "Helm unit tests passed"
    else
        print_error "Helm unit tests failed"
        exit 1
    fi
}

# Run integration tests
run_integration() {
    if [ "$SKIP_INTEGRATION" = true ]; then
        print_warning "Skipping integration tests (kubectl not available)"
        return
    fi
    
    print_status "Running integration tests..."
    if ./tests/integration/test-deployment.sh; then
        print_success "Integration tests passed"
    else
        print_error "Integration tests failed"
        exit 1
    fi
}

# Run security scans
run_security() {
    print_status "Running security scans..."
    
    # Install security tools if not present
    if ! command -v kube-score &> /dev/null; then
        print_status "Installing kube-score..."
        go install github.com/zegl/kube-score/cmd/kube-score@latest
    fi
    
    if ! command -v kubeaudit &> /dev/null; then
        print_status "Installing kubeaudit..."
        go install github.com/Shopify/kubeaudit/cmd/kubeaudit@latest
    fi
    
    if ! command -v polaris &> /dev/null; then
        print_status "Installing polaris..."
        go install github.com/FairwindsOps/polaris/cmd/polaris@latest
    fi
    
    if ./tests/security/security-scan.sh; then
        print_success "Security scans completed"
    else
        print_warning "Security scans completed with warnings"
    fi
}

# Run template tests
run_template_tests() {
    print_status "Running template tests..."
    
    # Test with different value files
    for values_file in tests/values/*.yaml; do
        if [ -f "$values_file" ]; then
            print_status "Testing with $(basename "$values_file")..."
            if helm template otel-test . -f "$values_file" --set tsuga.otlpEndpoint="https://test.com" --set tsuga.apiKey="test-key" > /dev/null; then
                print_success "Template test passed for $(basename "$values_file")"
            else
                print_error "Template test failed for $(basename "$values_file")"
                exit 1
            fi
        fi
    done
}

# Cleanup function
cleanup() {
    print_status "Cleaning up test resources..."
    kubectl delete namespace otel-test-* --ignore-not-found=true || true
    kubectl delete namespace otel-security-test-* --ignore-not-found=true || true
    kubectl delete namespace otel-integration-test-* --ignore-not-found=true || true
    helm uninstall otel-test --ignore-not-found=true || true
}

# Main execution
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --lint-only)
                LINT_ONLY=true
                shift
                ;;
            --unittest-only)
                UNITTEST_ONLY=true
                shift
                ;;
            --integration-only)
                INTEGRATION_ONLY=true
                shift
                ;;
            --security-only)
                SECURITY_ONLY=true
                shift
                ;;
            --skip-integration)
                SKIP_INTEGRATION=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --lint-only          Run only linting"
                echo "  --unittest-only      Run only unit tests"
                echo "  --integration-only   Run only integration tests"
                echo "  --security-only      Run only security scans"
                echo "  --skip-integration    Skip integration tests"
                echo "  --help               Show this help"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Run tests based on options
    if [ "$LINT_ONLY" = true ]; then
        run_lint
    elif [ "$UNITTEST_ONLY" = true ]; then
        run_unittest
    elif [ "$INTEGRATION_ONLY" = true ]; then
        run_integration
    elif [ "$SECURITY_ONLY" = true ]; then
        run_security
    else
        # Run all tests
        run_lint
        run_unittest
        run_template_tests
        run_integration
        run_security
    fi
    
    print_success "All tests completed successfully! 🎉"
}

# Run main function with all arguments
main "$@"
