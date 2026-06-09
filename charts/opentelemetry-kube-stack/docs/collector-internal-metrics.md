# Collector Internal Metrics: Design Notes

## Problem

The OpenTelemetry Operator permanently overrides `service.telemetry.metrics` in every collector
ConfigMap it manages. No matter what the `OpenTelemetryCollector` CR specifies under
`spec.config.service.telemetry.metrics`, the operator's mutating webhook replaces it with a
Prometheus pull reader on port 8888 before the ConfigMap is written to Kubernetes.

This means the intended OTLP-push path — configuring a `periodic` reader with an `otlp` exporter
in the CR — is silently discarded at deploy time. Relevant upstream history:

- [#3730](https://github.com/open-telemetry/opentelemetry-operator/issues/3730) — operator ignores
  user-configured readers and falls back to the deprecated `address` field; supposedly fixed by
  [PR #3874](https://github.com/open-telemetry/opentelemetry-operator/pull/3874)
- [#3913](https://github.com/open-telemetry/opentelemetry-operator/issues/3913) — PR #3874
  introduced a regression where the intermediate Go type dropped all non-metrics telemetry fields
  (e.g. `logs.level`)
- [PR #3915](https://github.com/open-telemetry/opentelemetry-operator/pull/3915) (merged April 16,
  2025, first shipped in v0.149.0) — replaces the overwrite with `mergo.Merge` to preserve
  user-specified telemetry fields

PR #3915 is included in the operator version this chart bundles (v0.152.0 via helm chart 0.114.1)
and does fix the orthogonal regression from #3913 (non-metrics fields like `logs.level` are now
preserved). However, **the metrics readers are still forced by the operator** — even with the fix,
the webhook replaces `service.telemetry.metrics.readers` with its own prometheus pull reader on
port 8888, discarding any user-configured periodic/OTLP reader. This was confirmed by inspecting
the live ConfigMap after deployment with operator v0.152.0.

## Solution: self-scrape pipeline

Because the operator always exposes collector internal metrics on `localhost:8888` (Prometheus
format), the reliable workaround is to have each collector scrape itself and forward the result
through a normal pipeline.

Each default collector config (`_default-deamonset-config.tpl`, `_default-statefulset-config.tpl`,
`_default-cluster-receiver-config.tpl`) includes:

**Receiver** — `prometheus/self` scrapes `localhost:8888` every 10 seconds. Named with the `/self`
suffix to avoid colliding with the statefulset's existing `prometheus` receiver (used by the Target
Allocator for dynamic scrape discovery).

**Processor chain** — matches the main metrics pipeline:
1. `memory_limiter` — backpressure safety (daemonset and statefulset only; cluster-receiver follows
   its existing pattern of omitting this processor)
2. `cumulativetodelta` — Prometheus exposes all counters as cumulative monotonic sums; this
   converts them to delta before export so Tsuga receives the expected incremental values
3. `resource/collector` — enriches every data point with:
   - `service.instance.id: ${POD_UID}` — globally unique per pod across the cluster and across
     time (see below)
   - `k8s.cluster.name` — set when `clusterName` is configured, same as the main pipeline
4. `batch` — standard batching before export

**Pipeline** — `metrics/collector` is a dedicated named pipeline so it stays isolated from
application metrics and can be toggled or modified independently.

## Why POD_UID, not POD_NAME

`POD_NAME` is only unique within a namespace at a given moment. It gets reused after rollouts and
pod restarts, which means two different collector processes can emit the same `service.instance.id`
over their lifetimes.

The OpenTelemetry semantic conventions
([service resource](https://opentelemetry.io/docs/specs/semconv/resource/service/)) recommend
using a UUID or a platform-specific ID that is tightly coupled to the service instance:

> "You could reuse an already-existing unique identifier tightly coupled with the service instance,
> like a Kubernetes pod UID."

`POD_UID` is assigned by the Kubernetes API server, is unique across the entire cluster, and is
never reused — even after the pod is deleted and recreated with the same name. It is injected via
the downward API (`metadata.uid`) and referenced as `${POD_UID}` in both the `resource/collector`
processor and the `service.telemetry.resource` block (the latter is currently overridden by the
operator webhook but is kept for forward compatibility).
