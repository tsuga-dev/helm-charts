{{/*
OpenTelemetry Collector Configuration Helper Templates
*/}}

{{/*
Generate environment variables for OpenTelemetry Collector
*/}}
{{- define "opentelemetry-kube-stack.collectorEnv" -}}
- name: TSUGA_OTLP_ENDPOINT
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_OTLP_ENDPOINT" "Values" .Values) }}
- name: MY_POD_IP
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.podIP
- name: TSUGA_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_API_KEY" "Values" .Values) }}
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
{{- end }}

{{/*
Generate Tsuga exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.tsugaExporters" -}}
otlphttp/tsuga:
  endpoint: ${TSUGA_OTLP_ENDPOINT}
  headers:
    Authorization: Bearer ${TSUGA_API_KEY}
  encoding: json
  compression: gzip
{{- end }}

{{/*
Generate Otel telemetry export
*/}}
{{- define "opentelemetry-kube-stack.otelTelemetry" -}}
resource:
  {{- if .Values.clusterName }}
  k8s.cluster.name: {{ .Values.clusterName }}
  {{- end}}
  service.instance.id: ${POD_UID}
metrics:
    readers:
    - periodic:
        exporter:
            otlp:
                protocol: http/protobuf
                headers:
                    Authorization: Bearer ${TSUGA_API_KEY}
                endpoint: ${TSUGA_OTLP_ENDPOINT}/v1/metrics
    - pull:
        exporter:
          prometheus:
            host: 0.0.0.0
            port: 8888
            without_scope_info: false
            without_type_suffix: false
            without_units: false
{{- end }}
