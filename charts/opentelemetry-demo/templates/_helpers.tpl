{{/*
Create a default fully qualified app name.
*/}}
{{- define "opentelemetry-demo.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}
