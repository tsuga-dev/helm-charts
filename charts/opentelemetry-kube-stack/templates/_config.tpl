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

Off by default, and opt-in rather than opt-out, because every detector worth
enabling can stop the collector from booting. The processor's Start() returns
the detector error — "If a configured resource detector fails, the error will
propagate and stop the collector from starting" — and a detector that returns a
partial result alongside an error has that result discarded. The feature gate
that used to suppress this, processor.resourcedetection.propagateerrors, was
removed in v0.150.0, below this chart's floor, so there is no escape hatch on
any version we can target.

That risk is not limited to cloud metadata endpoints. k8snode reads the node
object from the Kubernetes API and fails Start() if that call fails, and it
errors before Start() at all if its env var is unset. eks looks safe off-cloud
but is not: KUBERNETES_SERVICE_HOST is set on every Kubernetes cluster, so its
own check falls through to the Kubernetes API and can error on GKE, AKS or
kind. ec2, gcp, azure and aks do return an empty resource without error when
their metadata service is unreachable, so those are safe to list off-cloud —
but an on-cloud metadata hiccup at startup is still a hard failure.

Type name is resourcedetection because the canonical resource_detection does not
exist below v0.153.0, above this chart's floor. Note the direction: from v0.153.0
resource_detection is canonical and resourcedetection is the DEPRECATED alias, so
on the image this chart pins by default the collector logs a deprecation warning
for it at startup. cumulativetodelta is in the same position from v0.157.0. Both
are kept so a user pinning a floor-version image still gets a working config.

override: false everywhere, against the processor's own default of true, so a
detected value never replaces a cloud.* or host.* attribute an instrumented
application already set. Note that where two detectors can answer the same
attribute, the first one listed wins.

timeout is 15s rather than the factory default of 5s, the value the processor
README uses in its EKS example: the per-detector retry uses exponential backoff
with no maximum elapsed time, so a failing detector spends the whole budget.
*/}}
{{- define "opentelemetry-kube-stack.resourceDetection" -}}
resourcedetection:
  detectors:
    {{- toYaml .Values.resourceDetection.detectors | nindent 4 }}
  timeout: {{ .Values.resourceDetection.timeout | default "15s" }}
  override: false
{{- end }}

{{/*
Generate Tsuga exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.tsugaExporters" -}}
otlp_http/tsuga:
  endpoint: ${TSUGA_OTLP_ENDPOINT}
  headers:
    Authorization: Bearer ${TSUGA_API_KEY}
  encoding: json
  compression: gzip
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
Generate Otel telemetry export
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
