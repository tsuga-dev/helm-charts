# Collector Internal Metrics: Design Notes

Collector self-telemetry is configured through `service::telemetry`, rendered by the
`opentelemetry-kube-stack.otelTelemetry` helper in `templates/_config.tpl` and included by all three
default configs. There is no self-scrape pipeline.

The helper emits two things:

**`telemetry.resource`** — `k8s.cluster.name` (from `clusterName`) and `service.instance.id:
${POD_UID}`, as an inline map.

**`telemetry.metrics.readers`** — one `periodic` reader with an OTLP `http/protobuf` exporter
pointed at `${TSUGA_OTLP_ENDPOINT}/v1/metrics`, with a bearer-token header. Emitted only when the
Tsuga exporter is enabled; without credentials there is nowhere to push.

So `otelcol_*` series (`otelcol_exporter_sent_metric_points`, `otelcol_process_memory_rss`,
`otelcol_exporter_queue_size`, …) are pushed to Tsuga carrying `k8s.pod.name`, `k8s.namespace.name`
and `k8s.node.name`.

## Four things that look wrong and are not

**The resource block is an inline map, not a `resource.attributes` array.** The collector warns
about the inline format and prefers the array, but the operator types `resource` as
`map[string]*string` in its own intermediary struct. The array form fails to unmarshal there, and
the operator then replaces the whole telemetry block with an empty map — losing both attributes
rather than just the format. Migrate this together with the operator bump, not before.

**The reader endpoint carries `/v1/metrics` while the `otlp_http/tsuga` exporter takes the bare
endpoint.** These are different exporters with opposite conventions: the collector's `otlphttp`
exporter appends the signal path itself — "for metrics `/v1/metrics` will be appended"
([exporter README](https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/otlphttpexporter/README.md))
— while the SDK's declarative config expects the full URL, with
[the schema](https://github.com/open-telemetry/opentelemetry-configuration/blob/main/schema/common.yaml)
defining `endpoint` as "including the signal specific path". Making them consistent breaks
self-telemetry.

**Nothing is served on `:8888`.** Supplying a reader replaces the collector's default Prometheus one
rather than adding to it. This is also why the statefulset collector logs `Failed to scrape
Prometheus endpoint` for its placeholder scrape config, which targets `localhost:8888` until the
Target Allocator replaces it with real targets. Adding a pull reader back through
`<collector>.config.service.extraTelemetry` does not work — that merge is destination-wins and
`metrics` already exists — so it means editing the default config instead.

**Self-telemetry bypasses the pipelines deliberately.** `service::telemetry` configures the
collector's embedded SDK, which sits outside the pipeline graph. That is the point: these metrics
still arrive when a pipeline is wedged. Routing them through one would drop memory metrics to
`memory_limiter` exactly when memory is the problem, and feed metrics about exporting metrics back
through the exporter.

## Why POD_UID, not POD_NAME

`POD_NAME` is only unique within a namespace at a given moment. It is reused after rollouts and
restarts, so two different collector processes can emit the same `service.instance.id` over their
lifetimes. `POD_UID` is assigned by the API server, unique cluster-wide, and never reused — even
when a pod is recreated with the same name. The
[semantic conventions](https://opentelemetry.io/docs/specs/semconv/resource/service/) recommend
exactly this: "You could reuse an already-existing unique identifier tightly coupled with the
service instance, like a Kubernetes pod UID."

## Operator behaviour, for reference

The operator only supplies a Prometheus reader when the user configured none — `ServiceApplyDefaults`
in `internal/otelconfig/config.go` returns early when readers are present, and otherwise appends. It
never overwrites, at v0.152.0 or v0.156.0, and both call sites run the same function. A user-supplied
reader therefore survives on any operator this chart supports.

This was not always true: [#3730](https://github.com/open-telemetry/opentelemetry-operator/issues/3730)
had the operator ignore configured readers, and
[PR #3915](https://github.com/open-telemetry/opentelemetry-operator/pull/3915) (v0.149.0) is what
fixed it. Noted because an earlier version of this document claimed the readers were still forced,
and acting on that would mean deleting a working configuration or duplicating it.
