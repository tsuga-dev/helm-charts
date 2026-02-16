# Helm Charts Repository

This repository contains Helm charts for OpenTelemetry Kubernetes stack.

## Usage

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```bash
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages. You can then run `helm search repo
otel-charts` to see the charts.

### Prerequisites

Before installing the opentelemetry-kube-stack chart, you need to install:

1. **cert-manager** (required by the OpenTelemetry Operator):
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **OpenTelemetry Operator** (choose one option):

   **Option A: Install with this chart (recommended)**
   ```bash
   helm install my-opentelemetry-kube-stack tsuga-charts/opentelemetry-kube-stack \
     --set opentelemetry-operator.enabled=true
   ```

   **Option B: Install separately**
   ```bash
   kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
   ```
   Then install the chart:
   ```bash
   helm install my-opentelemetry-kube-stack tsuga-charts/opentelemetry-kube-stack
   ```

### Basic Installation

To install the opentelemetry-kube-stack chart:

```bash
helm install my-opentelemetry-kube-stack tsuga-charts/opentelemetry-kube-stack
```

To uninstall the chart:

```bash
helm uninstall my-opentelemetry-kube-stack
```

## Quick Deployment with Script

For a streamlined deployment experience, you can use the provided deployment script that handles prerequisites and configuration automatically:

```bash
cd charts/opentelemetry-kube-stack
./deploy.sh
```

The script will:
- Check and install required dependencies (cert-manager, OpenTelemetry operator)
- Prompt for namespace configuration
- Configure OpenTelemetry endpoint and API key
- Deploy the Helm chart with proper settings
- Verify the deployment

**Prerequisites:**
- `kubectl` configured and connected to your cluster
- `helm` installed
- Appropriate cluster permissions

## Available Charts

- **opentelemetry-kube-stack**: A comprehensive Helm chart for OpenTelemetry Kubernetes operator with namespace and secret management
- **opentelemetry-demo**: Demo stack wiring OpenTelemetry demo app with Tsuga-focused defaults
- **tsuga-spicy-gremlin**: Reusable chaos-style rotator for OpenTelemetry demo feature flags

## Chart Repository

The charts are published to: https://tsuga-dev.github.io/helm-charts/

## Contributing

Please see the main repository for contribution guidelines and chart development.
