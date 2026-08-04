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
Monitor credentials secret name for a MySQL database entry.
Kept separate from the PostgreSQL helper so the two engines can never collide on
a secret name when both are enabled with the same database entry name.
*/}}
{{- define "opentelemetry-database-monitoring.mysqlMonitorSecretName" -}}
{{- printf "%s-mysql-monitor-credentials" .name -}}
{{- end }}

{{/*
Monitor credentials secret name for a MongoDB database entry.
*/}}
{{- define "opentelemetry-database-monitoring.mongodbMonitorSecretName" -}}
{{- printf "%s-mongodb-monitor-credentials" .name -}}
{{- end }}

{{/*
Monitor credentials secret name for a Microsoft SQL Server database entry.
*/}}
{{- define "opentelemetry-database-monitoring.sqlserverMonitorSecretName" -}}
{{- printf "%s-sqlserver-monitor-credentials" .name -}}
{{- end }}

{{/*
Comma-separated union of the namespaces the Argo EventSource must watch, across
every enabled engine. Returned as a string because a template cannot return a
list; callers do `splitList ","` on it.

An explicit argoEvents.eventSource.watchNamespace overrides the union entirely.
*/}}
{{- define "opentelemetry-database-monitoring.watchNamespaces" -}}
{{- $root := . -}}
{{- $namespaces := list -}}
{{- if $root.Values.argoEvents.eventSource.watchNamespace -}}
{{- $namespaces = append $namespaces $root.Values.argoEvents.eventSource.watchNamespace -}}
{{- else -}}
{{- $entries := list -}}
{{- if $root.Values.postgres.enabled -}}
{{- $entries = concat $entries $root.Values.postgres.databases -}}
{{- end -}}
{{- if $root.Values.mysql.enabled -}}
{{- $entries = concat $entries $root.Values.mysql.databases -}}
{{- end -}}
{{- if $root.Values.mongodb.enabled -}}
{{- $entries = concat $entries $root.Values.mongodb.databases -}}
{{- end -}}
{{- if $root.Values.sqlserver.enabled -}}
{{- $entries = concat $entries $root.Values.sqlserver.databases -}}
{{- end -}}
{{- range $db := $entries -}}
{{- $ns := include "opentelemetry-database-monitoring.databaseNamespace" (merge (dict) $db (dict "Release" $root.Release)) -}}
{{- if not (has $ns $namespaces) -}}
{{- $namespaces = append $namespaces $ns -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- join "," $namespaces -}}
{{- end }}

{{/*
True when at least one database engine is enabled.
The Argo Events plumbing (EventBus, EventSource, RBAC) is shared across engines,
so it must be gated on the union rather than on postgres alone.
*/}}
{{- define "opentelemetry-database-monitoring.anyEngineEnabled" -}}
{{- if or .Values.postgres.enabled .Values.mysql.enabled .Values.mongodb.enabled .Values.sqlserver.enabled -}}
true
{{- end -}}
{{- end }}

{{/*
Resolve a stable monitor password, preferring an existing secret in the release or target namespace.

Context:
  .root       - root Helm context
  .db         - database entry
  .secretName - optional; defaults to the PostgreSQL monitor secret name
*/}}
{{- define "opentelemetry-database-monitoring.monitorPassword" -}}
{{- $root := .root -}}
{{- $db := .db -}}
{{- $secretName := default (include "opentelemetry-database-monitoring.monitorSecretName" $db) .secretName -}}
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
{{/*
default "" coerces an absent host to a string. A values override that replaces a
databases[] entry without repeating `host` otherwise yields nil here, and the
`contains` below fails the render with "invalid value; expected string".
*/}}
{{- $host := default "" $db.host -}}
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
