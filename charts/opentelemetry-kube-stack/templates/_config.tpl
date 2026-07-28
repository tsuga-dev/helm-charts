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
GOMEMLIMIT for a collector, as 80% of its memory limit, in bytes.

Input: the collector's effective resources map.

The memory_limiter processor's README calls this out: "It is highly recommended
to configure the GOMEMLIMIT environment variable as well as the memory_limiter
processor on every collector", with "GOMEMLIMIT should be set to 80% of the
hard memory limit of your collector". The Go runtime does not read cgroup
limits — GOMEMLIMIT defaults to math.MaxInt64, "which effectively disables the
memory limit" — so without it the garbage collector has no idea the container
has a budget, and the kernel reaches the limit before the GC feels any reason
to work harder. This is separate from memory_limiter's limit_percentage, which
does read the cgroup limit and sheds load; GOMEMLIMIT makes the runtime collect
harder instead of being OOM-killed.

Derived rather than hardcoded, so it follows an overridden
resources.limits.memory: a fixed value would throttle a collector given 4Gi
into constant GC, and mean nothing to one given 128Mi. Emitted as a plain byte
count, which the runtime reads as bytes. Renders empty when there is no memory
limit, or when the quantity is in a form not handled here — GOMEMLIMIT has no
sensible value without a limit to take a percentage of.
*/}}
{{- define "opentelemetry-kube-stack.goMemLimit" -}}
{{- $mem := "" -}}
{{- if and .limits .limits.memory -}}
{{- $mem = .limits.memory | toString -}}
{{- end -}}
{{- $bytes := int64 0 -}}
{{- if regexMatch "^[0-9]+$" $mem -}}
{{- $bytes = $mem | int64 -}}
{{- else if regexMatch "^[0-9]+Ki$" $mem -}}
{{- $bytes = mul (trimSuffix "Ki" $mem | int64) 1024 -}}
{{- else if regexMatch "^[0-9]+Mi$" $mem -}}
{{- $bytes = mul (trimSuffix "Mi" $mem | int64) 1048576 -}}
{{- else if regexMatch "^[0-9]+Gi$" $mem -}}
{{- $bytes = mul (trimSuffix "Gi" $mem | int64) 1073741824 -}}
{{- else if regexMatch "^[0-9]+K$" $mem -}}
{{- $bytes = mul (trimSuffix "K" $mem | int64) 1000 -}}
{{- else if regexMatch "^[0-9]+M$" $mem -}}
{{- $bytes = mul (trimSuffix "M" $mem | int64) 1000000 -}}
{{- else if regexMatch "^[0-9]+G$" $mem -}}
{{- $bytes = mul (trimSuffix "G" $mem | int64) 1000000000 -}}
{{- end -}}
{{- if gt ($bytes | int64) (int64 0) -}}
{{- div (mul $bytes 80) 100 -}}
{{- end -}}
{{- end -}}

{{/*
The GOMEMLIMIT env entry, omitted when no limit can be derived.
*/}}
{{- define "opentelemetry-kube-stack.goMemLimitEnv" -}}
{{- $limit := include "opentelemetry-kube-stack.goMemLimit" . -}}
{{- if $limit }}
- name: GOMEMLIMIT
  value: {{ $limit | quote }}
{{- end }}
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
Fail the render if a user-supplied collector image is older than v0.152.0.

The default configs use the component type names the collector adopted over
several releases, and the last one to land sets the floor: kubeletstats was
renamed to kubelet_stats in v0.152.0 (contrib CHANGELOG, v0.152.0,
"receiver/kubelet_stats: Rename receiver type from kubeletstats to
kubelet_stats"). An older collector rejects the config at startup with
`unknown type: "kubelet_stats"`, so the pod crash-loops rather than degrading.
The other names in use are older: k8s_attributes v0.146.0, file_log v0.149.0,
host_metrics and span_metrics v0.151.0. cumulativetodelta is the pre-rename
name, which every version we can target still accepts.

Only images a user pinned are checked, and only when the tag parses as semver.
A ":latest" or otherwise unparseable tag resolves at runtime and cannot be
verified here, and neither can the operator-supplied default, which is not a
chart value at all.

The floor is therefore 0.152.0 and not higher on purpose. It is both what this
config requires and what the operator subchart this chart bundles supplies by
default (opentelemetry-collector-k8s:0.152.1), so it never declares a minimum
that a default install does not meet. Raising it above what the operator ships
would be a claim nothing enforces, and would invite a later change to use a
component name the default image does not know.

The check runs regardless of customConfig, so an older image cannot be paired
with a hand-written config that would have suited it. That is deliberate rather
than overlooked: the floor is cheap to state and the combination is rare.
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
