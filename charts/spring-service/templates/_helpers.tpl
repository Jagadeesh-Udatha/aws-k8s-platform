{{- define "svc.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "svc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "svc.labels" -}}
{{ include "svc.selectorLabels" . }}
app.kubernetes.io/version: {{ include "svc.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "svc.tag" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{- define "svc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}{{ include "svc.name" . }}{{- else -}}default{{- end -}}
{{- end -}}

{{/* Name of the Secret the pod loads, or "" when the service has no secrets. */}}
{{- define "svc.secretName" -}}
{{- if .Values.secret.existingSecret -}}
{{ .Values.secret.existingSecret }}
{{- else if or .Values.secret.create .Values.externalSecret.enabled -}}
{{ include "svc.name" . }}-secrets
{{- end -}}
{{- end -}}
