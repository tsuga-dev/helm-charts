{{- define "opentelemetry-kube-stack.otelConfig" -}}
{{/* CASE 1 — User provides full config: use exactly that */}}
{{- if .customConfig }}
{{- toYaml .customConfig | nindent 0 }}
{{- else }}
{{/* CASE 2 — No full config: merge default + extra sections */}}
{{- $base := .defaultConfig }}
{{- $receivers  := default (dict) (index $base "receivers") }}
{{- $processors := default (dict) (index $base "processors") }}
{{- $exporters  := default (dict) (index $base "exporters") }}
{{- $extensions := default (dict) (index $base "extensions") }}
{{- $connectors := default (dict) (index $base "connectors") }}
{{- $service    := default (dict) (index $base "service") }}
{{- $servicectx := merge (dict "defaultService" $service) .service }}
{{/* Merge user overrides */}}
{{- if .extraReceivers  }} {{- $receivers  = merge $receivers  .extraReceivers  }} {{- end }}
{{- if .extraProcessors }} {{- $processors = merge $processors .extraProcessors }} {{- end }}
{{- if .extraExporters  }} {{- $exporters  = merge $exporters  .extraExporters  }} {{- end }}
{{- if .extraExtensions }} {{- $extensions = merge $extensions .extraExtensions }} {{- end }}
{{- if .extraConnectors }} {{- $connectors = merge $connectors .extraConnectors }} {{- end }}
{{/* ─── Output merged config ─────────────────────────── */}}
{{- if $receivers }}
receivers:
{{- toYaml $receivers | nindent 2 }}
{{- end }}
{{- if $processors }}
processors:
{{- toYaml $processors | nindent 2 }}
{{- end }}
{{- if $exporters }}
exporters:
{{- toYaml $exporters | nindent 2 }}
{{- end }}
{{- if $extensions }}
extensions:
{{- toYaml $extensions | nindent 2 }}
{{- end }}
{{- if $connectors }}
connectors:
{{- toYaml $connectors | nindent 2 }}
{{- end }}
{{- if $service }}
service:
{{- include "opentelemetry-kube-stack.buildService" $servicectx | trim | nindent 2 }}
{{- end }}
{{- end }} {{/* end if user full config */}}
{{- end }}
