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
Clears the SDK's placeholder service name so k8s_attributes can fill a real one.

The SDK side of the problem: semconv requires an SDK to emit
service.name=unknown_service:<executable> when nothing configured one. The
collector side: k8s_attributes writes an extracted attribute only when the key
is absent or empty (setResourceAttribute, processor.go), and it has no override
flag. A placeholder is neither absent nor empty, so every service.name
k8s_attributes derives for an instrumented pod is computed and discarded.

Deleting the placeholder first is what upstream recommends for exactly this —
contrib #43194, closed with the maintainers declining an override option in
favour of composing the two processors. That makes the ordering load-bearing:
this must run before k8s_attributes, never after.

Matched as a prefix, not equality, because the spec appends the executable name
— but anchored on the delimiter. The spec emits only "unknown_service" or
"unknown_service:<exe>", so a bare ^unknown_service would also swallow a real
service that merely starts with those letters, and silently rename it.
*/}}
{{- define "opentelemetry-kube-stack.clearUnknownService" -}}
{{- $stmt := `delete_key(resource.attributes, "service.name") where resource.attributes["service.name"] != nil and IsMatch(resource.attributes["service.name"], "^unknown_service(:|$)")` -}}
transform/clear_unknown_service:
  error_mode: ignore
  trace_statements:
    - '{{ $stmt }}'
  metric_statements:
    - '{{ $stmt }}'
  log_statements:
    - '{{ $stmt }}'
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
Fail the render if the given collector image is older than v0.157.0, the oldest
release carrying every component name the default configs use — cumulative_to_delta
arrived there, resource_detection in v0.153.0. An older collector rejects the
config at startup with `unknown type` and crash-loops.

Takes one image string: the image the collector being rendered will actually run.
Each collector template calls this for its own image, and only when it is
rendering the default config — a collector using customConfig is not bound by
what the default config happens to reference.

Only a parseable semver tag can be checked; ":latest" resolves at runtime and is
skipped.
*/}}
{{- define "opentelemetry-kube-stack.assertCollectorVersion" -}}
{{- if . -}}
{{- $tag := trimPrefix "v" (. | toString | splitList ":" | last) -}}
{{/*
Compare only the leading major.minor.patch: semver treats a suffixed tag like
0.156.0-amd64 as a prerelease, and excludes prereleases from a constraint that
has none, so comparing the whole tag would let it past the floor.
*/}}
{{- $core := regexFind "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag -}}
{{- if $core -}}
{{- if semverCompare "< 0.157.0" $core -}}
{{- fail (printf "collector image %q is older than v0.157.0. This chart's default config uses the cumulative_to_delta processor type, which collectors below v0.157.0 reject at startup with `unknown type`. Either pin a v0.157.0+ image, or stay on chart 0.10.x." .) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Collector self-telemetry, shared by all three collectors. This configures the
collector's own embedded SDK, which sits outside the pipeline graph, so these
metrics still arrive when a pipeline is wedged.

The endpoint carries the /v1/metrics path while the otlp_http/tsuga exporter
takes the bare endpoint. That asymmetry is required: the collector's otlphttp
exporter appends the signal path itself, whereas the SDK's declarative config
expects it already present. Harmonising them breaks self-telemetry.
*/}}
{{- define "opentelemetry-kube-stack.otelTelemetry" -}}
{{/*
An inline map, not the resource.attributes array the collector prefers. The
operator types resource as map[string]*string, so the array form fails to
unmarshal and it replaces the whole telemetry block with an empty map, dropping
both attributes. Migrate this with the operator bump, not before.
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
