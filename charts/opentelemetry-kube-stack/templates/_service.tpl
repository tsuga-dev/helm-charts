{{/*
Build the final service configuration:

Input context: $servicectx = merge (dict "defaultService" $service) .Values.cluster.config.service

- .defaultService : the default service map from your base config
- other keys      : user overrides (extraExtensions, pipelines, extraTelemetry, extraService, ...)

Behavior:
- Pipelines: default + extraReceivers/extraProcessors/extraExporters
- Telemetry: default + extraTelemetry
- Service: default + extraService (for additional top-level service fields)
*/}}

{{- define "opentelemetry-kube-stack.buildService" -}}

{{- $default := .defaultService }}
{{- $user := . }}

{{- $service := dict }}

{{/* 1. EXTENSIONS */}}
{{- $extensions := default (list) (index $default "extensions") }}
{{- if $user.extraExtensions }}
  {{- $extensions = concat $extensions $user.extraExtensions }}
{{- end }}
{{- $_ := set $service "extensions" $extensions }}


{{/* 2. PIPELINES */}}
{{- $pipelines := dict }}
{{- $userPipelines := default (dict) $user.pipelines }}

{{- range $pname, $pdefault := index $default "pipelines" }}

  {{- $puser := default (dict) (get $userPipelines $pname) }}

  {{/* Receivers: default + extraReceivers */}}
  {{- $receivers := default (list) (index $pdefault "receivers") }}
  {{- if $puser.extraReceivers }}
    {{- $receivers = concat $receivers $puser.extraReceivers }}
  {{- end }}

  {{/* Processors: default + extraProcessors */}}
  {{- $processors := default (list) (index $pdefault "processors") }}
  {{- if $puser.extraProcessors }}
    {{- $processors = concat $processors $puser.extraProcessors }}
  {{- end }}

  {{/* Exporters: default + extraExporters */}}
  {{- $exporters := default (list) (index $pdefault "exporters") }}
  {{- if $puser.extraExporters }}
    {{- $exporters = concat $exporters $puser.extraExporters }}
  {{- end }}

  {{- $_ := set $pipelines $pname (dict
      "receivers"  $receivers
      "processors" $processors
      "exporters"  $exporters
  ) }}

{{- end }}

{{/* Merge extraPipelines (completely new pipelines) */}}
{{- $extraPipelines := default (dict) $userPipelines.extraPipelines }}
{{- if $extraPipelines }}
  {{- range $pname, $pconfig := $extraPipelines }}
    {{- $_ := set $pipelines $pname (dict
        "receivers"  (default (list) $pconfig.receivers)
        "processors" (default (list) $pconfig.processors)
        "exporters"  (default (list) $pconfig.exporters)
    ) }}
  {{- end }}
{{- end }}

{{- $_ := set $service "pipelines" $pipelines }}


{{/* 3. TELEMETRY: default + extraTelemetry ONLY */}}
{{- $telemetry := default (dict) (index $default "telemetry") }}
{{- if $user.extraTelemetry }}
  {{- $telemetry = merge $telemetry $user.extraTelemetry }}
{{- end }}
{{- if $telemetry }}
  {{- $_ := set $service "telemetry" $telemetry }}
{{- end }}


{{ toYaml $service }}

{{- end }}
