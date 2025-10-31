# Getting Started with OpenTelemetry and Tsuga

This guide introduces you to OpenTelemetry, Tsuga, and the architecture of the OpenTelemetry Kubernetes Stack. By the end of this guide, you'll understand the fundamental concepts and be ready to set up observability in your cluster.

## Learning Objectives

- Understand what OpenTelemetry is and why it matters
- Learn about Tsuga and its role in observability
- Understand the recommended architecture pattern
- Know the prerequisites for deployment

## What is OpenTelemetry?

OpenTelemetry is an open-source observability framework that provides a unified set of APIs, SDKs, and tools to instrument, generate, collect, and export telemetry data (metrics, logs, and traces).

### Key Benefits

1. **Vendor Neutral**: Works with any observability backend
2. **Standardized**: Industry-standard for observability data
3. **Language Agnostic**: Support for 20+ programming languages
4. **Comprehensive**: Supports metrics, traces, and logs (the three pillars of observability)

### The Three Pillars of Observability

- **Traces**: Distributed request flows across services
- **Metrics**: Numerical measurements over time (CPU, memory, request rates)
- **Logs**: Event records with timestamps

## What is Tsuga?

Tsuga is an observability platform that receives, stores, and analyzes OpenTelemetry data. It provides:

- **Unified Data Collection**: Receives metrics, traces, and logs via OTLP (OpenTelemetry Protocol)
- **Data Visualization**: Dashboards and analytics for your telemetry
- **Storage**: Long-term retention of observability data
- **Analysis**: Querying and alerting capabilities

### Tsuga Integration

The Helm chart automatically configures OpenTelemetry Collectors to forward all telemetry data to your Tsuga endpoint using:

- **Protocol**: OTLP/HTTP (OpenTelemetry Protocol over HTTP)
- **Authentication**: Bearer token via API key
- **Endpoint**: Your Tsuga OTLP endpoint URL

## Architecture Overview

The OpenTelemetry Kubernetes Stack uses a **dual deployment pattern** recommended by OpenTelemetry:

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                      │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            Cluster Receiver (Deployment)             │   │
│  │  • Collects cluster-level metrics                    │   │
│  │  • Collects Kubernetes entity events                 │   │
│  │  • Forwards to Tsuga                                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           Agent (DaemonSet) - One per Node            │  │
│  │  • Collects host metrics                              │  │
│  │  • Collects Kubernetes object metrics                 │  │
│  │  • Receives application telemetry (OTLP)              │  │
│  │  • Collects container logs                            │  │
│  │  • Forwards directly to Tsuga                         │  │
│  └───────────────────────────────────────────────────────┘  │
│                         ▲                                   │
│                         |                                   │
│  ┌──────────────────────┴─────────────────────────────────┐ │
│  │              Your Applications                         │ |
│  │  • Send traces/metrics/logs via OTLP                   │ │
│  │  • Auto-instrumented or manual SDK                     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                  ┌─────────────────────┐
                  │   Tsuga Platform    │
                  │  (Your Endpoint)    │
                  └─────────────────────┘
```

### Agent (DaemonSet)

The Agent runs on every node in your cluster and:

- **Collects Host Metrics**: CPU, memory, disk, network (if enabled), process metrics (if enabled)
- **Collects Kubernetes Metrics**: Pod metrics via kubelet, cluster metrics
- **Receives Application Telemetry**: OTLP, Jaeger, Zipkin protocols
- **Collects Logs**: Container logs from `/var/log/pods`
- **Enriches Data**: Adds Kubernetes metadata (pod name, namespace, labels, etc.)

### Cluster Receiver (Deployment)

The Cluster Receiver is a centralized component that:

- **Collects Cluster-Level Metrics**: Uses `k8s_cluster` receiver to gather cluster-wide metrics
- **Collects Entity Events**: Captures Kubernetes object lifecycle events (pod creation, deletion, etc.)
- **Processes Data**: Applies resource attributes (including cluster name)
- **Forwards to Backend**: Sends cluster-level telemetry to Tsuga with proper authentication

**Note**: The Cluster Receiver operates independently from the Agent. It does not receive data from agents but collects its own cluster-level observability data.

### Data Flow

The system has two parallel data collection paths:

**Path 1 - Node-Level (Agent)**:
1. **Applications** → Send telemetry via OTLP to Agent
2. **Agent** → Collects host metrics, pod metrics, and logs, enriches with metadata
3. **Agent** → Forwards directly to Tsuga endpoint

**Path 2 - Cluster-Level (Cluster Receiver)**:
1. **Cluster Receiver** → Collects cluster-level metrics and entity events via `k8s_cluster` receiver
2. **Cluster Receiver** → Processes and forwards to Tsuga endpoint

**Both paths converge at**:
3. **Tsuga** → Stores, analyzes, and visualizes all observability data

## Why Use This Helm Chart?

This Helm chart provides:

✅ **Production-Ready Defaults**: Optimized configurations out of the box  
✅ **Security Best Practices**: Secure secret management and RBAC  
✅ **Easy Configuration**: Simple Helm values for common scenarios  
✅ **Flexibility**: Extensive customization options for advanced use cases  
✅ **Complete Observability**: Automatic collection of metrics, traces, and logs  
✅ **Kubernetes Integration**: Deep integration with Kubernetes metadata  

## Prerequisites Checklist

Before proceeding with installation, ensure you have:

### Required

- [ ] **Kubernetes Cluster** (version 1.19 or higher)
  ```bash
  kubectl version --client
  kubectl cluster-info
  ```

- [ ] **Helm** (version 3.0 or higher)
  ```bash
  helm version
  ```

- [ ] **kubectl** configured with cluster access
  ```bash
  kubectl get nodes
  ```

- [ ] **Tsuga Credentials**
  - API Key (Bearer token for authentication)
  - OTLP Endpoint URL (e.g., `https://your-tsuga-instance.com/v1/otlp`)

- [ ] **Cluster Permissions**
  - Ability to create namespaces
  - RBAC permissions (ClusterRole/ClusterRoleBinding)
  - Ability to create DaemonSets and Deployments

### Optional but Recommended

- [ ] **OpenTelemetry Operator** (will be installed as part of setup)
- [ ] **Monitoring Namespace** (create dedicated namespace for observability)
- [ ] **Resource Quotas** (for production environments)

### Verify Prerequisites

Run these commands to verify your environment:

```bash
# Check Kubernetes version
kubectl version --short

# Check Helm version
helm version

# Check cluster connectivity
kubectl get nodes

# Check current namespace context
kubectl config view --minify --output 'jsonpath={..namespace}'
```

## Next Steps

Now that you understand the fundamentals:

1. **Ready to install?** → Proceed to [Cluster Setup Guide](02-cluster-setup.md)
2. **Want more details?** → Continue reading this guide, then move to setup

## Key Concepts Summary

- **OpenTelemetry**: Vendor-neutral observability standard for metrics, traces, and logs
- **Tsuga**: Observability platform that receives and analyzes OpenTelemetry data
- **Agent (DaemonSet)**: Node-level collector running on every node
- **Cluster Receiver (Deployment)**: Centralized collector for cluster-level metrics and entity events
- **OTLP**: OpenTelemetry Protocol for transmitting telemetry data
- **Dual Deployment Pattern**: Recommended architecture combining agents and centralized receiver

## Common Terminology

- **Telemetry**: Observability data (metrics, traces, logs)
- **Instrumentation**: Code or configuration that generates telemetry
- **Collector**: Component that receives, processes, and exports telemetry
- **Receiver**: Component that receives telemetry (OTLP, Jaeger, Prometheus, etc.)
- **Processor**: Component that processes telemetry (batch, filter, enrich, etc.)
- **Exporter**: Component that sends telemetry to a backend (Tsuga, other systems)
- **Resource Attributes**: Metadata about the source of telemetry (service name, version, environment)

---

**Ready to set up your cluster?** Continue to [Cluster Setup Guide](02-cluster-setup.md)

