{{/*
Expand the name of the chart.
*/}}
{{- define "pull-secret.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pull-secret.fullname" -}}
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
{{- define "pull-secret.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pull-secret.labels" -}}
helm.sh/chart: {{ include "pull-secret.chart" . }}
{{ include "pull-secret.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: adapter
hyperfleet.io/adapter-type: pull-secret
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pull-secret.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pull-secret.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "pull-secret.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pull-secret.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the job
*/}}
{{- define "pull-secret.jobName" -}}
{{- default (include "pull-secret.fullname" .) .Values.job.name }}
{{- end }}

{{/*
Create the image reference with global override support.
Global image registry takes precedence over local registry.
*/}}
{{- define "pull-secret.image" -}}
{{- $registry := .Values.image.registry }}
{{- if .Values.global }}
{{- if .Values.global.image }}
{{- if .Values.global.image.registry }}
{{- $registry = .Values.global.image.registry }}
{{- end }}
{{- end }}
{{- end }}
{{- printf "%s/%s:%s" $registry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Create the secret name in GCP Secret Manager
Auto-generates as: hyperfleet-{cluster.id}-pull-secret if not provided
*/}}
{{- define "pull-secret.secretName" -}}
{{- if .Values.pullSecret.name }}
{{- .Values.pullSecret.name }}
{{- else }}
{{- printf "hyperfleet-%s-pull-secret" .Values.cluster.id }}
{{- end }}
{{- end }}
