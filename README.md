# Helm Charts Repository

This repository contains Helm charts for OpenTelemetry Kubernetes stack.

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

## Prerequisites

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```bash
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages. You can then run `helm search repo
tsuga-charts` to see the charts.

Before installing the opentelemetry-kube-stack chart, you need to install:

**cert-manager** (required by the OpenTelemetry Operator):
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
```

### OpenTelemetry Operator

You can pre-install the OpenTelemetry Operator or install it with this chart.

**Option A: Pre-Install**
```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

**Option B: Install with this chart** by setting `opentelemetry-operator.enabled=true` in your `values.yaml` file or on the command line when installing:
```bash
helm install my-opentelemetry-kube-stack tsuga-charts/opentelemetry-kube-stack \
  --set opentelemetry-operator.enabled=true
```

### Tsuga Secret

It is recommended to create a secret for the Tsuga API key and use it in the `values.yaml` file or on the command line when installing:

**Option A: Generate new secret (default)**

```bash
helm install my-otel-stack ./charts/opentelemetry-kube-stack \
  --set tsuga.otlpEndpoint="https://intake.<CLUSTER_ID>.tsuga.com:443/api/v1/otlp" \
  --set tsuga.apiKey="<TSUGA_API_KEY>"
```

**Option B: Use existing secret**
```bash
helm install my-otel-stack ./charts/opentelemetry-kube-stack \
  --set secret.create=false \
  --set secret.name="my-existing-secret" \
  --set secret.keyMapping.TSUGA_API_KEY="<API_KEY_SECRET_KEY>" \
  --set secret.keyMapping.TSUGA_OTLP_ENDPOINT="<OTLP_ENDPOINT_SECRET_KEY>"
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

You can check the [examples](https://github.com/tsuga-dev/helm-charts/tree/main/charts/opentelemetry-kube-stack/examples) folder for more details.

## Available Charts

Each chart has its own README with full configuration and values reference:

- **[opentelemetry-kube-stack](./charts/opentelemetry-kube-stack/README.md)**: OpenTelemetry Kubernetes operator with Tsuga integration — dual deployment pattern (agent DaemonSet + cluster receiver), secure credential management, and production-ready telemetry collection.
- **[opentelemetry-demo](./charts/opentelemetry-demo/README.md)**: Tsuga Observability Demo stack wiring the OpenTelemetry demo app with Tsuga-focused defaults.
- **[opentelemetry-database-monitoring](./charts/opentelemetry-database-monitoring/README.md)**: Deep monitoring for PostgreSQL via an OpenTelemetry sidecar collector — installs stored functions, a dedicated monitoring user, and emits metrics over OTLP.
- **[tsuga-spicy-gremlin](./charts/tsuga-spicy-gremlin/README.md)**: A minimal chart to run spicy-gremlin against OpenTelemetry Demo feature flags.

## Changelog

Each chart has its own `CHANGELOG.md` in [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format under its directory (e.g. `charts/opentelemetry-kube-stack/CHANGELOG.md`). When you bump a chart's `version` in `Chart.yaml`, you must add a corresponding entry to that chart's `CHANGELOG.md`; CI will fail otherwise.

Changelogs can be generated or updated with [git-cliff](https://git-cliff.org/) using the per-chart config in each chart directory (e.g. `charts/opentelemetry-kube-stack/cliff.toml`). From the repo root, run:

```bash
git cliff -c charts/<chart-name>/cliff.toml
```

Use [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat:`, `fix:`, `docs:`) for commits that touch a chart so they are categorized correctly.

## Chart Repository

The charts are published to: https://tsuga-dev.github.io/helm-charts/

## Contributing

Please see the main repository for contribution guidelines and chart development.
