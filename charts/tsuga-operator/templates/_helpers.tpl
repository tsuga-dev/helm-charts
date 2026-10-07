{{/*
Expand the name of the chart.
*/}}
{{- define "tsuga-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "tsuga-operator.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "tsuga-operator.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "tsuga-operator.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "tsuga-operator.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "tsuga-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tsuga-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: controller-manager
{{- end -}}

{{- define "tsuga-operator.serviceAccountName" -}}
{{- if .Values.manager.serviceAccount.create -}}
{{- default (include "tsuga-operator.fullname" .) .Values.manager.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.manager.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "tsuga-operator.metricsSecure" -}}
{{- if and .Values.manager.metrics.enabled .Values.manager.metrics.secure -}}true{{- end -}}
{{- end -}}
