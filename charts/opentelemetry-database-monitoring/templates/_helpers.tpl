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
Namespace where the target database pod (and injected sidecar) run.
*/}}
{{- define "opentelemetry-database-monitoring.databaseNamespace" -}}
{{- default $.Release.Namespace (index . "namespace") -}}
{{- end }}

{{/*
Space-separated list of the database engines this chart supports.

Each name must match a top-level values key that has `enabled` and `databases`.
The shared Argo Events plumbing is derived from this list, so adding an engine here
is what brings it into the EventBus, EventSource and RBAC gating.
*/}}
{{- define "opentelemetry-database-monitoring.engines" -}}
postgres mongodb
{{- end }}

{{/*
True when at least one database engine is enabled.

The Argo Events plumbing (EventBus, EventSource, RBAC) is shared across engines, so
it is gated on the union rather than on any single engine.
*/}}
{{- define "opentelemetry-database-monitoring.anyEngineEnabled" -}}
{{- $root := . -}}
{{- $any := false -}}
{{- range $engine := splitList " " (include "opentelemetry-database-monitoring.engines" $root) -}}
{{- if (index $root.Values $engine).enabled -}}
{{- $any = true -}}
{{- end -}}
{{- end -}}
{{- if $any -}}
true
{{- end -}}
{{- end }}

{{/*
Comma-separated union of the namespaces the Argo EventSource must watch, across
every enabled engine. Returned as a string because a template cannot return a list;
callers do `splitList ","` on it.

An explicit argoEvents.eventSource.watchNamespace overrides the union entirely.
*/}}
{{- define "opentelemetry-database-monitoring.watchNamespaces" -}}
{{- $root := . -}}
{{- $namespaces := list -}}
{{- if $root.Values.argoEvents.eventSource.watchNamespace -}}
{{- $namespaces = append $namespaces $root.Values.argoEvents.eventSource.watchNamespace -}}
{{- else -}}
{{- range $engine := splitList " " (include "opentelemetry-database-monitoring.engines" $root) -}}
{{- $config := index $root.Values $engine -}}
{{- if $config.enabled -}}
{{- range $db := $config.databases -}}
{{- $ns := include "opentelemetry-database-monitoring.databaseNamespace" (merge (dict) $db (dict "Release" $root.Release)) -}}
{{- if not (has $ns $namespaces) -}}
{{- $namespaces = append $namespaces $ns -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- join "," $namespaces -}}
{{- end }}

{{/*
Monitor credentials secret name for a PostgreSQL database entry.
*/}}
{{- define "opentelemetry-database-monitoring.monitorSecretName" -}}
{{- printf "%s-pg-monitor-credentials" .name -}}
{{- end }}

{{/*
Monitor credentials secret name for a MongoDB database entry.
Kept separate per engine so two engines can never collide on a secret name
when both are enabled with the same database entry name.
*/}}
{{- define "opentelemetry-database-monitoring.mongodbMonitorSecretName" -}}
{{- printf "%s-mongodb-monitor-credentials" .name -}}
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
Hostname used by setup Jobs to reach the database.
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
