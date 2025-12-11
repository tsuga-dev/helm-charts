# OpenTelemetry Kubernetes Instrumentation Guide

Welcome to the comprehensive guide for instrumenting Kubernetes clusters with OpenTelemetry and Tsuga. This documentation provides step-by-step instructions, practical examples, and best practices for achieving complete observability of your Kubernetes workloads.

## Table of Contents

1. [Getting Started](01-getting-started.md) - Introduction to OpenTelemetry, Tsuga, and the architecture
2. [Cluster Setup](02-cluster-setup.md) - Complete guide to installing and configuring the OpenTelemetry stack
3. [Application Instrumentation](03-application-instrumentation.md) - How to instrument your applications to send telemetry
4. [Configuration Examples](04-configuration-examples.md) - Practical configuration scenarios and patterns
5. [Troubleshooting](05-troubleshooting.md) - Common issues and solutions
6. [Advanced Topics](06-advanced-topics.md) - Advanced configuration and optimization

## Quick Start

If you're ready to get started immediately, here's the fastest path:

```bash
# 1. Install OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# 2. Add the Helm repository
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
helm repo update

# 3. Install the chart
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://your-tsuga-endpoint.com" \
  --set tsuga.apiKey="your-api-key-here"
```

For detailed explanations and configuration options, continue reading the guides below.

## Prerequisites

Before you begin, ensure you have:

- ✅ Kubernetes cluster (1.19+)
- ✅ Helm 3.0+ installed
- ✅ `kubectl` configured with cluster access
- ✅ Tsuga account with API key and endpoint
- ✅ Appropriate RBAC permissions

## What You'll Learn

By following these guides, you'll understand:

- **Architecture**: How the dual deployment pattern (Agent + Cluster Receiver) works
- **Setup**: How to install and configure OpenTelemetry in your cluster
- **Instrumentation**: How applications send telemetry data
- **Configuration**: How to customize collectors for your specific needs
- **Troubleshooting**: How to diagnose and fix common issues
- **Optimization**: How to tune performance and resource usage

## Documentation Structure

This documentation is organized into progressive guides:

- **Beginner**: Start with [Getting Started](01-getting-started.md) and [Cluster Setup](02-cluster-setup.md)
- **Intermediate**: Move to [Application Instrumentation](03-application-instrumentation.md) and [Configuration Examples](04-configuration-examples.md)
- **Advanced**: Explore [Troubleshooting](05-troubleshooting.md) and [Advanced Topics](06-advanced-topics.md)

## Additional Resources

- [Helm Chart README](../README.md) - Chart reference documentation
- [Examples Directory](../examples/) - Ready-to-use configuration examples
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting Guide](05-troubleshooting.md)
2. Review the [Configuration Examples](04-configuration-examples.md)
3. Verify your setup against [Cluster Setup](02-cluster-setup.md)
4. Consult the [Helm Chart README](../README.md) for parameter reference

---

**Ready to begin?** Start with [Getting Started](01-getting-started.md) to understand the fundamentals.

