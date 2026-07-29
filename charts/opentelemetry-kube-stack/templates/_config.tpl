{{/*
OpenTelemetry Collector Configuration Helper Templates
*/}}

{{/*
Generate environment variables for OpenTelemetry Collector
*/}}
{{- define "opentelemetry-kube-stack.collectorEnv" -}}
{{- if include "opentelemetry-kube-stack.tsugaEnabled" . }}
- name: TSUGA_OTLP_ENDPOINT
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_OTLP_ENDPOINT" "Values" .Values) }}
- name: TSUGA_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_API_KEY" "Values" .Values) }}
{{- end }}
- name: MY_POD_IP
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.podIP
- name: NODE_IP
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.hostIP
- name: POD_NAME
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: metadata.name
- name: POD_UID
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: metadata.uid
- name: K8S_NODE_NAME
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: spec.nodeName
{{- end }}

{{/*
The resource_detection processor, shared by all three collectors.

resource_detection is the canonical type from v0.153.0; the underscore-less
resourcedetection is now only a deprecated alias, which a collector accepts but
logs a warning for on every startup. This chart's collector floor is v0.157.0,
so the canonical name is always available.

override: false, against the processor's own default of true, so a detected
value never replaces a cloud.* or host.* attribute an instrumented application
already set.

timeout falls back to 15s rather than rendering as 0s, which would expire the
per-detector context before the first call and fail Start().
*/}}
{{- define "opentelemetry-kube-stack.resourceDetection" -}}
resource_detection:
  detectors:
    {{- toYaml .Values.resourceDetection.detectors | nindent 4 }}
  timeout: {{ .Values.resourceDetection.timeout | default "15s" }}
  override: false
{{- end }}

{{/*
The batch processor, shared by all three collectors.

send_batch_max_size defaults to the same value as send_batch_size so the timeout
can never assemble a batch larger than the exporter will accept. timeout is only
emitted when set, so the processor's own 200ms default applies otherwise.
*/}}
{{- define "opentelemetry-kube-stack.batch" -}}
batch:
  send_batch_size: {{ .Values.batch.sendBatchSize | default 5000 }}
  send_batch_max_size: {{ .Values.batch.sendBatchMaxSize | default 5000 }}
  {{- with .Values.batch.timeout }}
  timeout: {{ . }}
  {{- end }}
{{- end }}

{{/*
The Kubernetes metadata that k8s_attributes attaches, shared by all three
collectors. Emitted as a bare list, so callers supply their own indentation.
*/}}
{{- define "opentelemetry-kube-stack.k8sAttributesMetadata" -}}
{{ toYaml (.Values.k8sAttributes.metadata | default (list "k8s.namespace.name" "k8s.deployment.name" "k8s.statefulset.name" "k8s.daemonset.name" "k8s.cronjob.name" "k8s.job.name" "k8s.node.name" "k8s.pod.name" "k8s.pod.uid" "k8s.pod.start_time")) }}
{{- end }}

{{/*
Generate Tsuga exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.tsugaExporters" -}}
otlp_http/tsuga:
  endpoint: ${TSUGA_OTLP_ENDPOINT}
  headers:
    Authorization: Bearer ${TSUGA_API_KEY}
  encoding: {{ .Values.tsuga.encoding | default "json" }}
  compression: {{ .Values.tsuga.compression | default "gzip" }}
{{- end }}

{{/*
Fail the render if a pinned collector image is older than v0.157.0, the release
that renamed the cumulativetodelta processor to cumulative_to_delta — the newest
component name the default configs use. An older collector rejects the config at
startup with `unknown type: "cumulative_to_delta"` and crash-loops. Only images
with a parseable semver tag can be checked; ":latest" and operator-default
images resolve at runtime and cannot be verified here — which is why the three
collector templates now pin a concrete default tag rather than leaving it to the
registry.
*/}}
{{- define "opentelemetry-kube-stack.assertCollectorVersion" -}}
{{- range list .Values.image .Values.statefulset.image .Values.agent.image .Values.cluster.image -}}
{{- if . -}}
{{- $tag := trimPrefix "v" (. | toString | splitList ":" | last) -}}
{{/*
Compare only the leading major.minor.patch. A suffixed tag like 0.156.0-amd64 or
0.156.0-nightly.202607220306 is a prerelease as far as semverCompare is
concerned, and semver excludes prereleases from a constraint that has none — so
matching on the bare tag let every suffixed image below the floor through.
*/}}
{{- $core := regexFind "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag -}}
{{- if $core -}}
{{- if semverCompare "< 0.157.0" $core -}}
{{- fail (printf "collector image %q is older than v0.157.0. This chart's default config uses the cumulative_to_delta and resource_detection processor types, which collectors below v0.157.0 and v0.153.0 respectively reject at startup with `unknown type`. Either pin a v0.157.0+ image, or stay on chart 0.10.x." .) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Collector self-telemetry, shared by all three collectors.

This deliberately bypasses the pipelines. service::telemetry configures the
collector's own embedded OTel SDK, which sits outside the pipeline graph, so
these metrics still arrive when a pipeline is wedged — memory_limiter shedding
under pressure, an exporter queue full, a processor misconfigured. Routing them
through the pipelines instead would lose exactly the diagnostics that explain
the failure, and would feed metrics about exporting metrics back through the
exporter.

Note the endpoint: it carries the /v1/metrics path, while the otlp_http/tsuga
exporter takes the bare endpoint. That asymmetry is required, not an oversight.
The two are different exporters with opposite conventions:

  - the collector's otlphttp exporter takes a base URL and appends the signal
    path itself ("for metrics /v1/metrics will be appended")
  - the SDK's declarative config takes the full URL: the OTel Configuration
    schema defines OtlpHttpExporter.endpoint as "Configure endpoint, including
    the signal specific path", defaulting to http://localhost:4318/v1/{signal}

Harmonising them would silently break self-telemetry.
*/}}
{{- define "opentelemetry-kube-stack.otelTelemetry" -}}
{{- include "opentelemetry-kube-stack.assertCollectorVersion" . -}}
{{/*
The legacy inline map of attribute name to value, deliberately, even though the
collector has warned about it since v0.151.0 and prefers a resource.attributes
array.

The operator parses service::telemetry through its own intermediary struct,
where resource is typed map[string]*string (internal/otelconfig/config.go at
operator v0.152.0, which is what subchart 0.114.1 bundles). The array form does
not unmarshal into that, GetTelemetry returns nil, and ServiceApplyDefaults then
replaces the whole telemetry block with an empty map — dropping k8s.cluster.name
and service.instance.id rather than just failing to migrate them.

So the array form is strictly worse here until the operator subchart moves to a
release that understands it. Migrate this and the operator bump together.
*/}}
resource:
  k8s.cluster.name: {{ include "opentelemetry-kube-stack.clusterName" . }}
  service.instance.id: ${POD_UID}
{{- if include "opentelemetry-kube-stack.tsugaEnabled" . }}
metrics:
    readers:
    - periodic:
        exporter:
            otlp:
                protocol: http/protobuf
                headers:
                    - name: Authorization
                      value: Bearer ${TSUGA_API_KEY}
                endpoint: ${TSUGA_OTLP_ENDPOINT}/v1/metrics
{{- end }}
{{- end }}
