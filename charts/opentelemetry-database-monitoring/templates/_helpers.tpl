{{/*
Expand the name of the chart.
*/}}
{{- define "opentelemetry-database-monitoring.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "opentelemetry-database-monitoring.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "opentelemetry-database-monitoring.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opentelemetry-database-monitoring.labels" -}}
helm.sh/chart: {{ include "opentelemetry-database-monitoring.chart" . }}
{{ include "opentelemetry-database-monitoring.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opentelemetry-database-monitoring.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opentelemetry-database-monitoring.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{/*
Namespace where the target Postgres pod (and injected sidecar) run.
*/}}
{{- define "opentelemetry-database-monitoring.databaseNamespace" -}}
{{- default $.Release.Namespace (index . "namespace") -}}
{{- end }}

{{/*
Monitor credentials secret name for a database entry.
*/}}
{{- define "opentelemetry-database-monitoring.monitorSecretName" -}}
{{- printf "%s-pg-monitor-credentials" .name -}}
{{- end }}

{{/*
Resolve a stable monitor password, preferring an existing secret in the release or target namespace.
*/}}
{{- define "opentelemetry-database-monitoring.monitorPassword" -}}
{{- $root := .root -}}
{{- $db := .db -}}
{{- $secretName := include "opentelemetry-database-monitoring.monitorSecretName" $db -}}
{{- $targetNamespace := include "opentelemetry-database-monitoring.databaseNamespace" (merge (dict) $db (dict "Release" $root.Release)) -}}
{{- $password := randAlphaNum 24 -}}
{{- $releaseSecret := lookup "v1" "Secret" $root.Release.Namespace $secretName -}}
{{- if $releaseSecret -}}
{{- $password = index $releaseSecret.data "password" | b64dec -}}
{{- else -}}
{{- $targetSecret := lookup "v1" "Secret" $targetNamespace $secretName -}}
{{- if $targetSecret -}}
{{- $password = index $targetSecret.data "password" | b64dec -}}
{{- end -}}
{{- end -}}
{{- $password -}}
{{- end }}

{{/*
Hostname used by setup Jobs to reach Postgres.
Uses cluster DNS when the database runs in another namespace.
*/}}
{{- define "opentelemetry-database-monitoring.databaseHost" -}}
{{- $root := .root -}}
{{- $db := .db -}}
{{- $host := $db.host -}}
{{- if contains "." $host -}}
{{- $host -}}
{{- else -}}
{{- $targetNamespace := include "opentelemetry-database-monitoring.databaseNamespace" (merge (dict) $db (dict "Release" $root.Release)) -}}
{{- if ne $targetNamespace $root.Release.Namespace -}}
{{- printf "%s.%s.svc.cluster.local" $host $targetNamespace -}}
{{- else -}}
{{- $host -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Sanitize a namespace for use in Argo Events resource keys.
*/}}
{{- define "opentelemetry-database-monitoring.argoResourceSuffix" -}}
{{- . | replace "." "-" | replace "/" "-" -}}
{{- end }}
{{/*
Value expected on the sidecar.opentelemetry.io/inject pod annotation.
Uses releaseNamespace/sidecar-name when the database runs in another namespace.
*/}}
{{- define "opentelemetry-database-monitoring.sidecarInjectValue" -}}
{{- $root := .root -}}
{{- $db := .db -}}
{{- $sidecarName := index $db "sidecar-name" -}}
{{- $targetNamespace := include "opentelemetry-database-monitoring.databaseNamespace" (merge (dict) $db (dict "Release" $root.Release)) -}}
{{- if ne $targetNamespace $root.Release.Namespace -}}
{{- printf "%s/%s" $root.Release.Namespace $sidecarName -}}
{{- else -}}
{{- $sidecarName -}}
{{- end -}}
{{- end }}
