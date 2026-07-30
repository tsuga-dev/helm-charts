{{/*
Expand the name of the chart.
*/}}
{{- define "opentelemetry-kube-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "opentelemetry-kube-stack.fullname" -}}
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
{{- define "opentelemetry-kube-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opentelemetry-kube-stack.labels" -}}
helm.sh/chart: {{ include "opentelemetry-kube-stack.chart" . }}
{{ include "opentelemetry-kube-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opentelemetry-kube-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opentelemetry-kube-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "opentelemetry-kube-stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "opentelemetry-kube-stack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The service account to put on a collector (or TargetAllocator) spec, or empty
when the field should be left off entirely.

Non-empty whenever the chart knows which account the workloads must run as: the
one it creates, or one the user named. `serviceAccount.create: false` with an
explicit `serviceAccount.name` is the bring-your-own-account idiom, and the
chart's ClusterRoleBinding already binds that name -- so the collectors have to
be told to use it. Left off, the operator self-provisions an account of its own
naming instead, which nothing grants the ClusterRole to, and every Kubernetes
read is denied.

Empty only when `create` is false and no name was given, which leaves the field
off and the operator self-provisioning `<collector-name>-collector` (it does not
fall back to the namespace default -- see ServiceAccountName in
internal/manifests/collector/serviceaccount.go). That account is outside this
chart's ClusterRoleBinding, so the path stays broken, and it is left as-is
deliberately -- but not for the reason it might appear. `serviceAccountName`
already resolves to `default` here, so the ClusterRoleBinding ALREADY grants this
chart's cluster-wide permissions to the namespace default account that every
unconfigured pod inherits. Pointing the collectors at that account as well would
not fix anything, it would just run them under it. The real fix is to bind
nothing when no name was given, which changes rendered output for existing
releases and is the chart owner's call, not a bug fix's.
*/}}
{{- define "opentelemetry-kube-stack.collectorServiceAccountName" -}}
{{- if or .Values.serviceAccount.create .Values.serviceAccount.name -}}
{{- include "opentelemetry-kube-stack.serviceAccountName" . -}}
{{- end -}}
{{- end }}

{{/*
Get the secret name to use
*/}}
{{- define "opentelemetry-kube-stack.secretName" -}}
{{- .Values.secret.name | default "otel-secret" }}
{{- end }}

{{/*
Whether Tsuga is used by any collector. Returns "true" unless the Tsuga OTLP
exporter is explicitly disabled for every component. When empty, the Tsuga
secret is not referenced (env injection and internal-telemetry export are both
skipped), so no secret is required.
*/}}
{{- define "opentelemetry-kube-stack.tsugaEnabled" -}}
{{- if or (ne (index .Values "tsuga" "enabledForClusterReceiver") false) (ne (index .Values "tsuga" "enabledForDaemonset") false) (ne (index .Values "tsuga" "enabledForStatefulset") false) -}}
true
{{- end -}}
{{- end }}

{{/*
Get the secret key for a given key name
*/}}
{{- define "opentelemetry-kube-stack.secretKey" -}}
{{- $keyName := .keyName -}}
{{- if .Values.secret.create }}
{{- $keyName }}
{{- else }}
{{- index .Values.secret.keyMapping $keyName | default $keyName }}
{{- end }}
{{- end }}

{{/*
Validate that required secret values are provided
*/}}
{{- define "opentelemetry-kube-stack.validateSecretValues" -}}
{{- if and .Values.secret.validation.requireMandatoryKeys .Values.secret.create }}
{{- $missingKeys := list }}
{{- if not .Values.tsuga.apiKey }}
  {{- $missingKeys = append $missingKeys "TSUGA_API_KEY" }}
{{- end }}
{{- if not .Values.tsuga.otlpEndpoint }}
  {{- $missingKeys = append $missingKeys "TSUGA_OTLP_ENDPOINT" }}
{{- end }}
{{- if (len $missingKeys) }}
{{- fail (printf "Missing required configuration values for keys: %s. Please provide these values via --set flags or ensure they are set in values.yaml" (join ", " $missingKeys)) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
The cluster name, which is required.

Telemetry from a cluster that does not name itself cannot be told apart from
any other cluster's once it reaches Tsuga, and the omission only becomes
visible during an incident. Resolved through `required` at each point of use
so the failure happens at install time with one message.
*/}}
{{- define "opentelemetry-kube-stack.clusterName" -}}
{{- required "clusterName is required: it identifies this cluster in telemetry. Set it with --set clusterName=<name> or in your values file." .Values.clusterName -}}
{{- end }}

{{/*
Validate resource names to prevent conflicts and ensure Kubernetes compliance
*/}}
{{- define "opentelemetry-kube-stack.validateResourceNames" -}}
{{- if .Values.validation.enabled }}
{{- $fullname := include "opentelemetry-kube-stack.fullname" . }}
{{- $maxLength := int (.Values.validation.maxNameLength | default 63) }}
{{- if gt (len $fullname) $maxLength }}
{{- fail (printf "Resource name '%s' exceeds maximum length limit of %d characters. Current length: %d" $fullname $maxLength (len $fullname)) }}
{{- end }}
{{- if .Values.validation.enforceNamingConventions }}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $fullname) }}
{{- fail (printf "Resource name '%s' does not match Kubernetes naming convention (lowercase alphanumeric and hyphens only)" $fullname) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate consistent component labels
*/}}
{{- define "opentelemetry-kube-stack.componentLabels" -}}
app.kubernetes.io/name: {{ include "opentelemetry-kube-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ .component | default "otel-collector" }}
app.kubernetes.io/part-of: {{ include "opentelemetry-kube-stack.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "debug.dump" -}}
{{- $obj := . -}}
# DEBUG DUMP:
{{- range $line := splitList "\n" (toYaml $obj) }}
# {{ $line }}
{{- end }}
{{- end }}
