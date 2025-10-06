# Helm Charts Repository

This repository contains Helm charts for OpenTelemetry Kubernetes stack.

## Usage

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```bash
helm repo add otel-charts https://antoninbruneau.github.io/otel_charts
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages. You can then run `helm search repo
otel-charts` to see the charts.

To install the opentelemetry-kube-stack chart:

```bash
helm install my-opentelemetry-kube-stack otel-charts/opentelemetry-kube-stack
```

To uninstall the chart:

```bash
helm uninstall my-opentelemetry-kube-stack
```

## Available Charts

- **opentelemetry-kube-stack**: A comprehensive Helm chart for OpenTelemetry Kubernetes operator with namespace and secret management

## Chart Repository

The charts are published to: https://antoninbruneau.github.io/otel_charts

## Contributing

Please see the main repository for contribution guidelines and chart development.
