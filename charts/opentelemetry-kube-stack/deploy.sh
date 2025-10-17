#!/bin/bash

# OpenTelemetry Kubernetes Stack Deployment Script
# This script checks prerequisites and deploys the OpenTelemetry Helm chart

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CHART_NAME="opentelemetry-kube-stack"
RELEASE_NAME="otel-stack"
CERT_MANAGER_NAMESPACE="cert-manager"
OTEL_OPERATOR_NAMESPACE="opentelemetry-operator-system"

# Global variable for namespace (will be set by user input)
NAMESPACE=""

# Global variables for OpenTelemetry configuration
OTEL_ENDPOINT=""
OTEL_API_KEY=""

# Global variables for collection settings
COLLECT_NETWORK=""
COLLECT_PROCESSES=""

# Global variable for cluster name
CLUSTER_NAME=""

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo -e "\n${PURPLE}========================================${NC}"
    echo -e "${PURPLE}  OpenTelemetry Kubernetes Stack Deploy${NC}"
    echo -e "${PURPLE}========================================${NC}\n"
}

print_step() {
    local step=$1
    local message=$2
    echo -e "\n${CYAN}[Step ${step}]${NC} ${message}"
    echo -e "${BLUE}----------------------------------------${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if kubectl is available and working
check_kubectl() {
    if ! command_exists kubectl; then
        print_status $RED "❌ kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_status $RED "❌ kubectl is not configured or cluster is not accessible"
        exit 1
    fi
    
    print_status $GREEN "✅ kubectl is available and configured"
}

# Function to get namespace from user
get_namespace() {
    print_step "0" "Namespace Configuration"
    
    echo -e "${YELLOW}Please specify the namespace for the OpenTelemetry deployment.${NC}"
    echo -e "${BLUE}Note: The namespace will be created if it doesn't exist.${NC}"
    
    while true; do
        read -p "Enter namespace (default: otel): " -r input_namespace
        if [[ -z "$input_namespace" ]]; then
            NAMESPACE="otel"
            break
        elif [[ "$input_namespace" =~ ^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$ ]]; then
            NAMESPACE="$input_namespace"
            break
        else
            print_status $RED "❌ Invalid namespace format. Namespace must be lowercase alphanumeric with hyphens only."
            echo -e "${YELLOW}Valid format: lowercase letters, numbers, and hyphens (not starting/ending with hyphen)${NC}"
        fi
    done
    
    print_status $GREEN "✅ Using namespace: $NAMESPACE"
}

# Function to check and configure Tsuga endpoint and API key
configure_tsuga_settings() {
    print_step "0.5" "Tsuga Configuration"
    
    # Check if values.yaml exists
    local has_values_file=false
    local current_endpoint=""
    local current_api_key=""
    local needs_configuration=false
    
    if [[ -f "values.yaml" ]]; then
        has_values_file=true
        print_status $GREEN "✅ Found values.yaml file"
        
        # Check if values.yaml has Tsuga configuration
        current_endpoint=$(grep -E "^\s*otlpEndpoint:" values.yaml | sed 's/.*: *"\(.*\)".*/\1/' | head -1)
        current_api_key=$(grep -E "^\s*apiKey:" values.yaml | sed 's/.*: *"\(.*\)".*/\1/' | head -1)
        
        # Set global variables from current values
        OTEL_ENDPOINT="$current_endpoint"
        OTEL_API_KEY="$current_api_key"
        
        # Show current configuration
        echo -e "${BLUE}Current Tsuga Configuration:${NC}"
        echo -e "  Endpoint: ${CYAN}${current_endpoint:-'Not set'}${NC}"
        echo -e "  API Key: ${CYAN}${current_api_key:+[CONFIGURED]}${current_api_key:-'Not set'}${NC}"
        echo ""
        
        # Check if both values are provided
        if [[ -z "$current_endpoint" ]] || [[ "$current_endpoint" == "null" ]] || [[ "$current_endpoint" == '""' ]]; then
            needs_configuration=true
        fi
        
        if [[ -z "$current_api_key" ]] || [[ "$current_api_key" == "null" ]] || [[ "$current_api_key" == '""' ]]; then
            needs_configuration=true
        fi
        
        # If configuration is needed, ask user
        if [[ "$needs_configuration" == "true" ]]; then
            echo -e "${YELLOW}Tsuga configuration is incomplete or missing.${NC}"
            echo -e "${BLUE}Please provide the required OpenTelemetry settings:${NC}"
        else
            read -p "Do you want to reconfigure Tsuga settings? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status $GREEN "✅ Using existing OpenTelemetry configuration"
                return 0
            fi
        fi
    else
        print_status $YELLOW "⚠️  No values.yaml file found in current directory"
        echo -e "${BLUE}Please provide the required OpenTelemetry settings:${NC}"
        needs_configuration=true
    fi
    
    # Configure endpoint
    if [[ -z "$current_endpoint" ]] || [[ "$current_endpoint" == "null" ]] || [[ "$current_endpoint" == '""' ]] || [[ "$needs_configuration" == "true" ]]; then
        echo -e "${YELLOW}Tsuga endpoint is not configured.${NC}"
        echo -e "${BLUE}Please provide your OpenTelemetry endpoint URL:${NC}"
        echo -e "${CYAN}Example: https://your-otel-endpoint.com:4318/v1/traces${NC}"
        
        while true; do
            read -p "Enter OTLP endpoint URL: " -r otlp_endpoint
            if [[ -n "$otlp_endpoint" ]]; then
                # Validate URL format
                if [[ "$otlp_endpoint" =~ ^https?:// ]]; then
                    # Store in global variable
                    OTEL_ENDPOINT="$otlp_endpoint"
                    print_status $GREEN "✅ Tsuga endpoint configured: $otlp_endpoint"
                    break
                else
                    print_status $RED "❌ Invalid URL format. Please include http:// or https://"
                fi
            else
                print_status $RED "❌ Endpoint URL cannot be empty"
            fi
        done
    else
        print_status $GREEN "✅ OpenTelemetry endpoint already configured: $current_endpoint"
    fi
    
    # Configure API key
    if [[ -z "$current_api_key" ]] || [[ "$current_api_key" == "null" ]] || [[ "$current_api_key" == '""' ]] || [[ "$needs_configuration" == "true" ]]; then
        echo -e "${YELLOW}Tsuga API key is not configured.${NC}"
        echo -e "${BLUE}Please provide your OpenTelemetry API key:${NC}"
        echo -e "${CYAN}This will be used for authentication with your OpenTelemetry backend.${NC}"
        
        while true; do
            read -s -p "Enter API key: " -r api_key
            echo  # Add newline after silent input
            if [[ -n "$api_key" ]]; then
                # Store in global variable
                OTEL_API_KEY="$api_key"
                print_status $GREEN "✅ Tsuga API key configured"
                break
            else
                print_status $RED "❌ API key cannot be empty"
            fi
        done
    else
        print_status $GREEN "✅ Tsuga API key already configured"
    fi
    
    # Show final configuration
    echo -e "\n${BLUE}Final Tsuga Configuration:${NC}"
    echo -e "  Endpoint: ${CYAN}${OTEL_ENDPOINT:-'Using values.yaml'}${NC}"
    if [[ -n "$OTEL_API_KEY" ]]; then
        echo -e "  API Key: ${CYAN}[CONFIGURED]${NC}"
    else
        echo -e "  API Key: ${CYAN}Using values.yaml${NC}"
    fi
    echo ""
}

# Function to configure collection settings
configure_collection_settings() {
    print_step "0.6" "Collection Settings Configuration"
    
    echo -e "${YELLOW}Configure what data to collect from your Kubernetes nodes.${NC}"
    echo -e "${BLUE}These settings control additional host-level metrics collection.${NC}"
    echo ""
    
    # Ask about network collection
    echo -e "${CYAN}Network Metrics Collection:${NC}"
    echo -e "${BLUE}Collect network interface statistics, connection counts, and network errors.${NC}"
    echo -e "${YELLOW}This provides insights into network performance and connectivity issues.${NC}"
    echo ""
    
    while true; do
        read -p "Collect network metrics? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            COLLECT_NETWORK="true"
            print_status $GREEN "✅ Network metrics collection enabled"
            break
        elif [[ $REPLY =~ ^[Nn]$ ]] || [[ -z "$REPLY" ]]; then
            COLLECT_NETWORK="false"
            print_status $YELLOW "⚠️  Network metrics collection disabled"
            break
        else
            print_status $RED "❌ Please answer with 'y' for yes or 'n' for no"
        fi
    done
    
    echo ""
    
    # Ask about process collection
    echo -e "${CYAN}Process Metrics Collection:${NC}"
    echo -e "${BLUE}Collect process-level metrics including CPU, memory, and disk usage.${NC}"
    echo -e "${YELLOW}This provides detailed insights into running processes and resource consumption.${NC}"
    echo ""
    
    while true; do
        read -p "Collect process metrics? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            COLLECT_PROCESSES="true"
            print_status $GREEN "✅ Process metrics collection enabled"
            break
        elif [[ $REPLY =~ ^[Nn]$ ]] || [[ -z "$REPLY" ]]; then
            COLLECT_PROCESSES="false"
            print_status $YELLOW "⚠️  Process metrics collection disabled"
            break
        else
            print_status $RED "❌ Please answer with 'y' for yes or 'n' for no"
        fi
    done
    
    # Show final collection settings
    echo -e "\n${BLUE}Final Collection Settings:${NC}"
    echo -e "  Network Metrics: ${CYAN}${COLLECT_NETWORK}${NC}"
    echo -e "  Process Metrics: ${CYAN}${COLLECT_PROCESSES}${NC}"
    echo ""
}

# Function to get cluster name from user
get_cluster_name() {
    print_step "0.7" "Cluster Name Configuration"
    
    echo -e "${YELLOW}Please specify the name of your Kubernetes cluster.${NC}"
    echo -e "${BLUE}This will be used as a resource attribute in your telemetry data.${NC}"
    echo -e "${CYAN}This helps identify which cluster the data is coming from.${NC}"
    echo ""
    
    while true; do
        read -p "Enter cluster name: " -r input_cluster_name
        if [[ -n "$input_cluster_name" ]]; then
            # Validate cluster name format (alphanumeric, hyphens, underscores)
            if [[ "$input_cluster_name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-_]*[a-zA-Z0-9])?$ ]]; then
                CLUSTER_NAME="$input_cluster_name"
                break
            else
                print_status $RED "❌ Invalid cluster name format. Use alphanumeric characters, hyphens, and underscores only."
                echo -e "${YELLOW}Valid format: letters, numbers, hyphens, and underscores (not starting/ending with hyphen or underscore)${NC}"
            fi
        else
            print_status $RED "❌ Cluster name cannot be empty"
        fi
    done
    
    print_status $GREEN "✅ Using cluster name: $CLUSTER_NAME"
    echo ""
}

# Function to check and display current Kubernetes context
check_kubectl_context() {
    print_step "1" "Checking Kubernetes Context"
    
    local current_context
    current_context=$(kubectl config current-context)
    local current_cluster
    current_cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "unknown")
    
    print_status $YELLOW "Current Kubernetes Context: ${current_context}"
    print_status $YELLOW "Current Cluster: ${current_cluster}"
    
    echo -e "\n${YELLOW}⚠️  Please confirm this is the correct cluster before proceeding.${NC}"
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status $RED "Deployment cancelled by user"
        exit 1
    fi
    
    print_status $GREEN "✅ Context confirmed"
}

# Function to check if cert-manager is installed
check_cert_manager() {
    print_step "2" "Checking cert-manager Installation"
    
    if kubectl get namespace "$CERT_MANAGER_NAMESPACE" >/dev/null 2>&1; then
        print_status $GREEN "✅ cert-manager namespace exists"
        
        local running_pods
        running_pods=$(kubectl get pods -n "$CERT_MANAGER_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        
        if [[ $running_pods -gt 0 ]]; then
            print_status $GREEN "✅ cert-manager is running ($running_pods pods)"
            return 0
        else
            print_status $YELLOW "⚠️  cert-manager namespace exists but no running pods found"
        fi
    else
        print_status $YELLOW "⚠️  cert-manager is not installed"
    fi
    
    echo -e "\n${YELLOW}cert-manager is required for OpenTelemetry operator.${NC}"
    read -p "Install cert-manager? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_status $RED "❌ cert-manager is required. Exiting."
        exit 1
    fi
    
    print_status $BLUE "Installing cert-manager..."
    
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
    
    print_status $BLUE "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n "$CERT_MANAGER_NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=webhook -n "$CERT_MANAGER_NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cainjector -n "$CERT_MANAGER_NAMESPACE" --timeout=300s
    
    print_status $GREEN "✅ cert-manager installed successfully"
}

# Function to check if OpenTelemetry operator is installed
check_otel_operator() {
    print_step "3" "Checking OpenTelemetry Operator Installation"
    
    if kubectl get namespace "$OTEL_OPERATOR_NAMESPACE" >/dev/null 2>&1; then
        print_status $GREEN "✅ OpenTelemetry operator namespace exists"
        
        local running_pods
        running_pods=$(kubectl get pods -n "$OTEL_OPERATOR_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        
        if [[ $running_pods -gt 0 ]]; then
            print_status $GREEN "✅ OpenTelemetry operator is running ($running_pods pods)"
            return 0
        else
            print_status $YELLOW "⚠️  OpenTelemetry operator namespace exists but no running pods found"
        fi
    else
        print_status $YELLOW "⚠️  OpenTelemetry operator is not installed"
    fi
    
    echo -e "\n${YELLOW}OpenTelemetry operator is required for this deployment.${NC}"
    read -p "Install OpenTelemetry operator? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_status $RED "❌ OpenTelemetry operator is required. Exiting."
        exit 1
    fi
    
    print_status $BLUE "Installing OpenTelemetry operator..."
    
    # Install OpenTelemetry operator
    kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
    
    print_status $BLUE "Waiting for OpenTelemetry operator to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opentelemetry-operator -n "$OTEL_OPERATOR_NAMESPACE" --timeout=300s
    
    print_status $GREEN "✅ OpenTelemetry operator installed successfully"
}

# Function to check if Helm is available
check_helm() {
    if ! command_exists helm; then
        print_status $RED "❌ Helm is not installed or not in PATH"
        print_status $YELLOW "Please install Helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    print_status $GREEN "✅ Helm is available"
}

# Function to deploy the Helm chart
deploy_helm_chart() {
    print_step "4" "Deploying OpenTelemetry Helm Chart"
    
    # Build Helm command with Tsuga configuration
    local helm_cmd=""
    local helm_args=""
    
    # Add Tsuga configuration if provided
    if [[ -n "$OTEL_ENDPOINT" ]]; then
        helm_args="$helm_args --set tsuga.otlpEndpoint=\"$OTEL_ENDPOINT\""
    fi
    
    if [[ -n "$OTEL_API_KEY" ]]; then
        helm_args="$helm_args --set tsuga.apiKey=\"$OTEL_API_KEY\""
    fi

    if [[ -n "$OTEL_ENDPOINT" && -n "$OTEL_API_KEY" ]]; then
        helm_args="$helm_args --set secret.create=true"
    fi
    
    # Add collection settings if configured
    if [[ -n "$COLLECT_NETWORK" ]]; then
        helm_args="$helm_args --set agent.collectNetwork=$COLLECT_NETWORK"
    fi
    
    if [[ -n "$COLLECT_PROCESSES" ]]; then
        helm_args="$helm_args --set agent.collectProcesses=$COLLECT_PROCESSES"
    fi
    
    # Add cluster name if provided
    if [[ -n "$CLUSTER_NAME" ]]; then
        helm_args="$helm_args --set clusterName=\"$CLUSTER_NAME\""
    fi
    
    # Check if release already exists
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_status $YELLOW "⚠️  Release '$RELEASE_NAME' already exists in namespace '$NAMESPACE'"
        read -p "Upgrade existing release? (Y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_status $RED "Deployment cancelled by user"
            exit 1
        fi
        
        print_status $BLUE "Upgrading existing release..."
        helm_cmd="helm upgrade $RELEASE_NAME . -n $NAMESPACE --create-namespace $helm_args"
    else
        print_status $BLUE "Installing new release..."
        helm_cmd="helm install $RELEASE_NAME . -n $NAMESPACE --create-namespace $helm_args"
    fi
    
    # Show the command being executed
    if [[ -n "$helm_args" ]]; then
        print_status $BLUE "Using configuration from user input"
        # Mask API key in displayed command
        local masked_cmd="$helm_cmd"
        if [[ -n "$OTEL_API_KEY" ]]; then
            masked_cmd=$(echo "$helm_cmd" | sed "s/--set tsuga\.apiKey=\"[^\"]*\"/--set tsuga.apiKey=\"[MASKED]\"/")
        fi
        echo -e "${CYAN}Helm command: $masked_cmd${NC}"
        
        # Show collection settings summary
        if [[ -n "$COLLECT_NETWORK" ]] || [[ -n "$COLLECT_PROCESSES" ]] || [[ -n "$CLUSTER_NAME" ]]; then
            echo -e "\n${BLUE}Configuration Summary:${NC}"
            if [[ -n "$CLUSTER_NAME" ]]; then
                echo -e "  Cluster Name: ${CYAN}${CLUSTER_NAME}${NC}"
            fi
            if [[ -n "$COLLECT_NETWORK" ]]; then
                echo -e "  Network Metrics: ${CYAN}${COLLECT_NETWORK}${NC}"
            fi
            if [[ -n "$COLLECT_PROCESSES" ]]; then
                echo -e "  Process Metrics: ${CYAN}${COLLECT_PROCESSES}${NC}"
            fi
        fi
    fi
    
    # Execute the Helm command
    eval "$helm_cmd"
    
    print_status $GREEN "✅ Helm chart deployed successfully"
}

# Function to verify deployment
verify_deployment() {
    print_step "5" "Verifying Deployment"
    
    print_status $BLUE "Checking deployment status..."
    
    # Wait for pods to be ready
    print_status $BLUE "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opentelemetry-kube-stack -n "$NAMESPACE" --timeout=300s || true
    
    # Show deployment status
    echo -e "\n${CYAN}Deployment Status:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opentelemetry-kube-stack
    
    echo -e "\n${CYAN}OpenTelemetryCollector Resources:${NC}"
    kubectl get opentelemetrycollectors -n "$NAMESPACE" || echo "No OpenTelemetryCollector resources found"
    
    print_status $GREEN "✅ Deployment verification completed"
}

# Function to show next steps
show_next_steps() {
    echo -e "\n${PURPLE}========================================${NC}"
    echo -e "${PURPLE}  Deployment Complete! 🎉${NC}"
    echo -e "${PURPLE}========================================${NC}"
    
    echo -e "\n${CYAN}Next Steps:${NC}"
    echo -e "1. Check pod status: ${BLUE}kubectl get pods -n $NAMESPACE${NC}"
    echo -e "2. View logs: ${BLUE}kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=opentelemetry-kube-stack${NC}"
    echo -e "3. Check OpenTelemetryCollector: ${BLUE}kubectl get opentelemetrycollectors -n $NAMESPACE${NC}"
    echo -e "4. View Helm release: ${BLUE}helm list -n $NAMESPACE${NC}"
    
    echo -e "\n${CYAN}Useful Commands:${NC}"
    echo -e "• Uninstall: ${BLUE}helm uninstall $RELEASE_NAME -n $NAMESPACE${NC}"
    echo -e "• Upgrade: ${BLUE}helm upgrade $RELEASE_NAME . -n $NAMESPACE${NC}"
    echo -e "• Status: ${BLUE}helm status $RELEASE_NAME -n $NAMESPACE${NC}"
}

# Main execution
main() {
    print_header
    
    # Get namespace from user
    get_namespace
    
    # Configure OpenTelemetry settings
    configure_tsuga_settings
    
    # Configure collection settings
    configure_collection_settings
    
    # Get cluster name
    get_cluster_name
    
    # Check prerequisites
    check_kubectl
    check_helm
    
    # Check context and get user confirmation
    check_kubectl_context
    
    # Check and install dependencies
    check_cert_manager
    check_otel_operator
    
    # Deploy the chart
    deploy_helm_chart
    
    # Verify deployment
    verify_deployment
    
    # Show next steps
    show_next_steps
}

# Run main function
main "$@"
