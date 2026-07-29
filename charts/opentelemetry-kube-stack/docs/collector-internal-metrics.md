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

## Current approach: `service::telemetry`

There is no self-scrape pipeline. Internal telemetry is configured through `service::telemetry`
alone, rendered by the `opentelemetry-kube-stack.otelTelemetry` helper in `templates/_config.tpl`
and included by all three default configs (`_default-deamonset-config.tpl`,
`_default-statefulset-config.tpl`, `_default-cluster-receiver-config.tpl`).

The helper emits two things:

**`telemetry.resource`** — a map of `k8s.cluster.name` (from `clusterName`) and
`service.instance.id: ${POD_UID}` (see below).

This is the legacy inline-map format. The collector has warned about it since v0.151.0 and prefers
a `resource.attributes` array, but the chart cannot move yet: the operator types `resource` as
`map[string]*string` in its own intermediary struct, so the array form fails to unmarshal,
`GetTelemetry` returns nil, and `ServiceApplyDefaults` replaces the whole telemetry block with an
empty map — losing both attributes instead of merely failing to migrate them. Verified against
operator v0.152.0, the version subchart 0.114.1 bundles. Migrate this together with the operator
bump, not before.

**`telemetry.metrics.readers`** — a single `periodic` reader with an OTLP `http/protobuf` exporter
pointed at `${TSUGA_OTLP_ENDPOINT}/v1/metrics` with a bearer-token header. Emitted only when the
Tsuga exporter is enabled; without credentials there is nowhere to push.

This is the configuration the chart *asks* for. As described above, the operator webhook still
replaces `readers` with its own Prometheus pull reader on `:8888`, so in practice internal metrics
are exposed for scraping rather than pushed. The block is kept so the intended behaviour lands as
soon as the operator stops overriding it. Getting those metrics into Tsuga today requires scraping
`:8888` yourself — e.g. a `prometheus` receiver added via `agent.config.extraReceivers` plus a
matching pipeline, or the Target Allocator statefulset.

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
the downward API (`metadata.uid`) and referenced as `${POD_UID}` in the
`service.telemetry.resource` block.
