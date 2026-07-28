# Collector Internal Metrics: Design Notes

## Summary

The chart configures the collector's own metrics to be pushed to Tsuga over OTLP through
`service::telemetry.metrics.readers`, and the OpenTelemetry Operator preserves that
configuration. Earlier versions of this document claimed the operator overrode it. That was
wrong, and the sections below record what the operator actually does, so the claim is not
reintroduced.

## What the operator does with `service::telemetry`

The operator only supplies its own metrics reader when the user has configured none. From
`internal/otelconfig/config.go` at operator v0.152.0, the version this chart bundles via
opentelemetry-operator helm chart 0.114.1:

```go
if tel.Metrics.Address != "" || len(tel.Metrics.Readers) != 0 {
    // The user already set the address or the readers, so we don't need to do anything
    logger.V(1).Info("telemetry configuration already provided by user, skipping defaults", ...)
    return events, nil
}
```

Only when `readers` is empty does it add a Prometheus pull reader on port 8888, and it merges
that with `mergo.Merge` without `WithOverride`, so it does not clobber neighbouring fields
either. The same function runs from both call sites that matter — the defaulting webhook
(`internal/webhook/collector_webhook.go`) and the ConfigMap builder
(`internal/manifests/collector/configmap.go`) — so the CR and the rendered ConfigMap agree.

This behaviour comes from [PR #3915](https://github.com/open-telemetry/opentelemetry-operator/pull/3915),
which replaced an unconditional overwrite with a merge. Relevant history:

- [#3730](https://github.com/open-telemetry/opentelemetry-operator/issues/3730) — operator ignored
  user-configured readers and fell back to the deprecated `address` field
- [#3913](https://github.com/open-telemetry/opentelemetry-operator/issues/3913) — the first fix
  regressed by dropping non-metrics telemetry fields such as `logs.level`
- [PR #3915](https://github.com/open-telemetry/opentelemetry-operator/pull/3915) — merged April 2025,
  and the behaviour quoted above, which is what operator v0.152.0 does. The only later commits to
  that file adjust metric shape and promote a gate; neither restores overwriting.

`service::telemetry.logs` is untouched on this version for a structural reason: the operator's
intermediate telemetry type models only `metrics` and `resource`, with no `logs` field at all, so
there is nothing in the code path that could rewrite it.

## Current configuration

Internal telemetry is configured through `service::telemetry` alone, with no self-scrape
pipeline. It is rendered by the `opentelemetry-kube-stack.otelTelemetry` helper in
`templates/_config.tpl` and included by all three default configs.

**`telemetry.resource`** — `k8s.cluster.name` from `clusterName`, and
`service.instance.id: ${POD_UID}`.

**`telemetry.metrics.readers`** — a single `periodic` reader with an OTLP `http/protobuf` exporter
pointed at `${TSUGA_OTLP_ENDPOINT}/v1/metrics` with a bearer-token header. Emitted only when the
Tsuga exporter is enabled, since without credentials there is nowhere to push. The `/v1/metrics`
suffix is required because the telemetry reader sends metrics directly rather than through OTLP
base-path expansion.

One side effect worth knowing: because the chart supplies a `periodic` reader and no `pull`
reader, the operator's port lookup falls through to its default of 8888, and it still opens a
monitoring port on the Service and container that nothing serves. Setting
`spec.observability.metrics.disablePrometheusAnnotations: true` stops the `prometheus.io/*`
annotations advertising it, but does not remove the port itself — there is no CR field that does.

## Why `POD_UID`, not `POD_NAME`

`POD_NAME` is only unique within a namespace at a given moment. It is reused after rollouts and
pod restarts, so two different collector processes can emit the same `service.instance.id` over
their lifetimes.

The OpenTelemetry semantic conventions
([service resource](https://opentelemetry.io/docs/specs/semconv/resource/service/)) prefer a random
UUID but allow an inherent identifier where stability matters:

> "Implementations, such as SDKs, are recommended to generate a random Version 1 or Version 4 UUID,
> but are free to use an inherent unique ID as the source of this value if stability is desirable."

They also caution that a Collector should not set `service.instance.id` when it cannot unambiguously
determine the instance — which is not the case here, since the value identifies the collector's own
pod rather than a workload's.

`POD_UID` is assigned by the API server, is unique across the cluster, and is never reused, even
when a pod is recreated with the same name. It is injected through the downward API
(`metadata.uid`) and referenced as `${POD_UID}`.

## The collector's own logs are not exported

Only metrics are pushed. The collector's logs stay on stdout for `kubectl logs`, and this is a
deliberate stop rather than an oversight.

Exporting them is technically possible: `service::telemetry.logs.processors` accepts declarative
log record processors with an OTLP exporter, it is wired to a real `LoggerProvider`, and no
feature gate guards it. What is not possible is exporting warning-and-above over OTLP while
keeping stdout useful. The OTLP path is a tee off the console logger, and the tee is deliberately
gated on the console core accepting the record first — from `logger_tee.go` in the collector's
`service/telemetry`:

> "we intentionally do not use zapcore.NewTee here… The provided Zap core may have sampling or a
> minimum log level applied to it, so in order to maintain consistency, we need to ensure that
> only the logs accepted by the provided core are copied to the log.LoggerProvider."

So `logs.level` is a single control for both destinations. Exporting warnings and above would mean
setting the level to `warn` globally, which removes info-level output from `kubectl logs` for
everyone — the first thing anyone reads when a collector misbehaves. Exporting at `info` instead
would push a high-volume, low-value stream into ingest.

Note that the upstream `docs/observability.md` at this collector version is stale on this point
and still says logs cannot be emitted at all; the code above contradicts it.

If you need collector logs centrally, the route that does not touch `logs.level` is to collect
them as ordinary container logs: `agent.collectOtelLogs=true` removes the filelog exclusion on the
collector's own container. That keeps `kubectl logs` intact and is filterable downstream like any
other log source. It is off by default for a reason, though — the agent then ingests its own
output, which is a feedback loop that produces container-parser errors — so weigh it against
simply reading `kubectl logs` when something breaks.
