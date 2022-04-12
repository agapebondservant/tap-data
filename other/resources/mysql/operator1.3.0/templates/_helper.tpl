{{/*
Expand the name of the chart.
*/}}
{{- define "tanzu-mysql-operator.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tanzu-mysql-operator.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tanzu-mysql-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tanzu-mysql-operator.labels" -}}
helm.sh/chart: {{ include "tanzu-mysql-operator.chart" . }}
{{ include "tanzu-mysql-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tanzu-mysql-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tanzu-mysql-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "tanzu-mysql-operator.serviceAccountName" -}}
tanzu-mysql-operator
{{- end }}

{{- define "tanzu-mysql-operator.instanceRepo" -}}
{{ list  (.Values.registry | trimSuffix "/") "tanzu-mysql-instance" | compact | join "/" }}
{{- end }}