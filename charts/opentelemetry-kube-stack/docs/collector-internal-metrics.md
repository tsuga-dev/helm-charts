# Collector Internal Metrics: Design Notes

## Background

The chart configures collector self-telemetry through `service::telemetry`, using a `periodic`
reader with an OTLP exporter that pushes to Tsuga. Internal metrics reach Tsuga this way — verified
on a live cluster: the rendered ConfigMap contains the chart's reader, and `otelcol_*` series
(e.g. `otelcol_exporter_sent_metric_points`, `otelcol_process_memory_rss`,
`otelcol_exporter_queue_size`) arrive with `k8s.pod.name`, `k8s.namespace.name` and
`k8s.node.name` attached.

**An earlier version of this document claimed the operator's mutating webhook replaces
`service.telemetry.metrics.readers` with a Prometheus pull reader on port 8888, discarding the OTLP
block. That was wrong**, and it is corrected here because acting on it would have meant either
deleting a working configuration or building a redundant second mechanism beside it.

The operator only supplies a Prometheus reader when the user has configured none. From
`internal/otelconfig/config.go`, identical at operator v0.152.0 and v0.156.0:

```go
if tel.Metrics.Address != "" || len(tel.Metrics.Readers) != 0 {
    // The user already set the address or the readers, so we don't need to do anything
    return events, nil
}
...
reader := AddPrometheusMetricsEndpoint(host, port)
tel.Metrics.Readers = append(tel.Metrics.Readers, reader)
```

It returns early when readers are present, and otherwise *appends*. It never overwrites. Both call
sites — the defaulting webhook and the ConfigMap builder — run the same function.

Upstream history, for context on why the confusion was plausible:

- [#3730](https://github.com/open-telemetry/opentelemetry-operator/issues/3730) — operator ignored
  user-configured readers and fell back to the deprecated `address` field
- [#3913](https://github.com/open-telemetry/opentelemetry-operator/issues/3913) — the fix for #3730
  introduced a regression that dropped non-metrics telemetry fields such as `logs.level`
- [PR #3915](https://github.com/open-telemetry/opentelemetry-operator/pull/3915) (first shipped in
  v0.149.0) — replaced the overwrite with a merge that preserves user-specified telemetry fields

So on any operator this chart supports, a user-supplied reader survives.

Re-confirmed at chart 0.11.0 against operator v0.152.0: all three collectors' ConfigMaps contain
only the chart's `periodic` OTLP reader, both `telemetry.resource` attributes are intact, and the
collectors hold established connections to the intake on `:443` with no export failures logged.

Because the chart supplies a reader, the collector's own default Prometheus reader is replaced
rather than added to, so **nothing is served on `:8888`**. That is also why the statefulset
collector logs `Failed to scrape Prometheus endpoint` for its placeholder scrape config, which
targets `localhost:8888` until the Target Allocator replaces it with real targets.

## Why self-telemetry bypasses the pipelines

`service::telemetry` configures the collector's own embedded OTel SDK, which sits outside the
pipeline graph. There is no internal-telemetry receiver to wire into `service::pipelines`; routing
self-telemetry through a pipeline would require exposing it as Prometheus on `:8888` and scraping
`localhost` with a `prometheus` receiver.

That is deliberately not done:

- **It would die with the pipeline it is meant to observe.** `memory_limiter` runs first in every
  default pipeline and sheds load under memory pressure, so memory metrics would disappear exactly
  when memory is the problem. A full exporter queue would take `otelcol_exporter_queue_size` and
  `otelcol_exporter_send_failed_*` with it.
- **It would feed back on itself.** Metrics about exporting metrics would pass through the exporter
  and generate more; `otelcol_cumulativetodelta_datapoints` would flow through `cumulativetodelta`.
- **It would cost fidelity and timeliness.** Round-tripping OTLP through Prometheus and back loses
  temporality and exemplar detail, and adds a scrape interval of latency.
- **It would add moving parts** — the `:8888` reader, a receiver, a scrape job, and the operator's
  port and annotation handling — in place of one config block.

## Endpoint asymmetry

The reader's endpoint carries the signal path (`${TSUGA_OTLP_ENDPOINT}/v1/metrics`) while the
`otlp_http/tsuga` exporter takes the bare endpoint. This is required, because they are different
exporters with opposite conventions:

- the collector's `otlphttp` exporter takes a **base URL** and appends the signal path itself —
  "for metrics `/v1/metrics` will be appended" ([exporter README](https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/otlphttpexporter/README.md))
- the SDK's declarative config takes the **full URL** — the OTel Configuration schema defines
  `OtlpHttpExporter.endpoint` as "Configure endpoint, including the signal specific path", with a
  default of `http://localhost:4318/v1/{signal}`
  ([schema/common.yaml](https://github.com/open-telemetry/opentelemetry-configuration/blob/main/schema/common.yaml))

Making the two consistent would silently break self-telemetry.

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

This is the configuration the chart asks for, and — per the Background section above — the
configuration that is actually deployed. No self-scrape of `:8888` is needed.

If you do want a scrapable endpoint alongside the push path, note that
`<collector>.config.service.extraTelemetry` will not give you one: that merge is destination-wins,
and since `metrics` already exists in the default config the supplied `readers` list is dropped
(verified by trying it). Adding a pull reader means editing the default config, not merging into it.

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
