# Collector Internal Metrics: Design Notes

## Background

The operator used to overwrite `service.telemetry.metrics` in every collector ConfigMap it managed,
replacing whatever the CR asked for with a Prometheus pull reader on port 8888 and silently
discarding the intended OTLP-push path. Upstream history:

- [#3730](https://github.com/open-telemetry/opentelemetry-operator/issues/3730) — operator ignores
  user-configured readers and falls back to the deprecated `address` field; addressed by
  [PR #3874](https://github.com/open-telemetry/opentelemetry-operator/pull/3874)
- [#3913](https://github.com/open-telemetry/opentelemetry-operator/issues/3913) — PR #3874
  introduced a regression where the intermediate Go type dropped all non-metrics telemetry fields
  (e.g. `logs.level`)
- [PR #3915](https://github.com/open-telemetry/opentelemetry-operator/pull/3915) (merged April 16,
  2025, first shipped in v0.149.0) — replaces the overwrite with `mergo.Merge` to preserve
  user-specified telemetry fields

**This is fixed in the operator version the chart bundles (v0.152.0 via helm chart 0.114.1), and the
chart's OTLP reader now survives to the ConfigMap.** `ServiceApplyDefaults` in
`internal/otelconfig/config.go` returns early when the parsed telemetry already has readers
(`if tel.Metrics.Address != "" || len(tel.Metrics.Readers) != 0`), so it never reaches the code that
appends a Prometheus reader. Verified on a live cluster running this chart at 0.11.0: all three
collectors' ConfigMaps contain only the chart's `periodic` OTLP reader, both `telemetry.resource`
attributes are intact, and nothing is listening on `:8888`.

An earlier revision of this document claimed the readers were still forced. That no longer
reproduces; the note is kept because it explains why the block is shaped the way it is.

One consequence worth knowing: because there is no Prometheus reader, `:8888` is not served. The
statefulset collector's placeholder scrape config targets `localhost:8888` and logs
`Failed to scrape Prometheus endpoint` until the Target Allocator replaces it with real targets.

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

This reaches the ConfigMap unchanged, so internal metrics are pushed to Tsuga rather than exposed
for scraping. Confirmed live: the collectors hold established connections to the intake on :443 and
log no export failures.

Note that supplying readers replaces the collector's own default reader rather than adding to it, so
there is no Prometheus endpoint alongside the push path. Adding one back through
`<collector>.config.service.extraTelemetry` does not work: that merge is destination-wins, and since
`metrics` already exists in the default the supplied `readers` list is dropped. Getting a scrapable
endpoint today means editing the default config, not merging into it.

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
