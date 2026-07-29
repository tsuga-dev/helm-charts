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
The resourcedetection processor, shared by all three collectors.

Type name is resourcedetection, not the canonical resource_detection, which does
not exist below v0.153.0 — above this chart's collector floor. Same position as
cumulativetodelta, canonical from v0.157.0.

override: false, against the processor's own default of true, so a detected
value never replaces a cloud.* or host.* attribute an instrumented application
already set.

timeout falls back to 15s rather than rendering as 0s, which would expire the
per-detector context before the first call and fail Start().
*/}}
{{- define "opentelemetry-kube-stack.resourceDetection" -}}
resourcedetection:
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
Fail the render if a pinned collector image is older than v0.152.0, the release
that renamed the kubeletstats receiver to kubelet_stats — the newest component
name the default configs use. An older collector rejects the config at startup
with `unknown type: "kubelet_stats"` and crash-loops. Only images with a
parseable semver tag can be checked; untagged/":latest"/operator-default images
resolve at runtime and cannot be verified here.
*/}}
{{- define "opentelemetry-kube-stack.assertCollectorVersion" -}}
{{- range list .Values.image .Values.statefulset.image .Values.agent.image .Values.cluster.image -}}
{{- if . -}}
{{- $tag := trimPrefix "v" (. | toString | splitList ":" | last) -}}
{{- if regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag -}}
{{- if semverCompare "< 0.152.0" $tag -}}
{{- fail (printf "collector image %q is < v0.152.0; this chart's default config uses the kubelet_stats receiver type, which older collectors reject with `unknown type`. Pin a v0.152.0+ image." .) -}}
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
