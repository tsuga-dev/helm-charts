# Target Allocator Feature Design

**Date:** 2026-03-12
**Chart:** `opentelemetry-kube-stack`
**Status:** Approved

## Overview

Add support for the OpenTelemetry Target Allocator by deploying a standalone `TargetAllocator` CR paired with an `OpenTelemetryCollector` CR in `statefulset` mode. Both resources are gated on a single `targetAllocator.enabled: true` flag.

## Architecture

Two new Kubernetes resources are created when `targetAllocator.enabled: true`:

1. **`TargetAllocator` CR** (`opentelemetry.io/v1alpha1`) — decouples Prometheus service discovery from metric collection, distributes targets evenly across collector replicas.
2. **`OpenTelemetryCollector` CR** (`statefulset` mode) — receives its scrape targets from the TargetAllocator via HTTP SD. Linked to the TA via the `opentelemetry.io/target-allocator: <ta-name>` label.

## New Helm Values

```yaml
targetAllocator:
  enabled: false
  spec:                          # passthrough to TargetAllocator CR spec
    allocationStrategy: consistent-hashing
    prometheusCR:
      enabled: false             # enables ServiceMonitor/PodMonitor discovery
      serviceMonitorSelector: {}
      podMonitorSelector: {}

statefulset:                     # config for the paired StatefulSet collector
  image: ""
  replicas: 1
  extraEnvs: []
  customConfig: {}
  config:
    extraReceivers: {}
    extraProcessors: {}
    extraExporters: {}
    extraConnectors: {}
    service:
      extraExtensions: []
      pipelines:
        metrics:
          extraReceivers: []
          extraProcessors: []
          extraExporters: []
        extraPipelines: {}
  resources: {}
  nodeSelector: {}
  tolerations: {}
  affinity: {}
```

## New Templates

### `templates/target-allocator.yaml`
Renders the `TargetAllocator` CR. Sets `spec.serviceAccount` to the shared service account. Passes through `targetAllocator.spec` for all other fields.

### `templates/statefulset.yaml`
Renders the `OpenTelemetryCollector` CR in `statefulset` mode. Follows the same config merge pattern as `daemonset.yaml` and `cluster-receiver.yaml`. Adds `opentelemetry.io/target-allocator: <ta-name>` label to link it to the TA.

### `templates/_default-statefulset-config.tpl`
Default OTel config: `prometheus` receiver (HTTP SD pointing to the TA), `batch` processor, tsuga exporter. Metrics pipeline only by default.

## Linking Mechanism

The operator links the TargetAllocator to the collector via this label on the `OpenTelemetryCollector` CR:

```yaml
labels:
  opentelemetry.io/target-allocator: {{ fullname }}-ta
```

The TargetAllocator assigns targets across replicas. Each replica queries its HTTP SD endpoint and scrapes its assigned targets.

## RBAC

No new ClusterRole or ClusterRoleBinding. The `TargetAllocator` CR references the existing shared service account via `spec.serviceAccount`. When `targetAllocator.spec.prometheusCR.enabled: true`, the existing ClusterRole gains:

```yaml
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors", "podmonitors"]
  verbs: ["get", "list", "watch"]
```

## Data Flow

```
ServiceMonitor/PodMonitor CRs (optional)
        │
        ▼
TargetAllocator (Deployment)
  - discovers targets
  - distributes evenly across replicas
        │
        ▼  HTTP SD endpoints (per replica)
StatefulSet Collector replicas
  - prometheus receiver scrapes assigned targets
  - ships metrics → tsuga exporter
```
