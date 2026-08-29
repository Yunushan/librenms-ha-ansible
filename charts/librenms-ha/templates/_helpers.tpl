{{/* Expand the chart name. */}}
{{- define "librenms-ha.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a release-qualified name. */}}
{{- define "librenms-ha.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "librenms-ha.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Common labels. */}}
{{- define "librenms-ha.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
{{ include "librenms-ha.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end }}

{{/* Selector labels. */}}
{{- define "librenms-ha.selectorLabels" -}}
app.kubernetes.io/name: {{ include "librenms-ha.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Render an immutable image reference. */}}
{{- define "librenms-ha.image" -}}
{{- if .Values.image.requireDigest }}
{{- if not (regexMatch "^sha256:[a-f0-9]{64}$" .Values.image.digest) -}}
{{- fail "image.digest must be a full sha256 digest when image.requireDigest=true" -}}
{{- end -}}
{{ printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else if .Values.image.digest }}
{{ printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else }}
{{ printf "%s:%s" .Values.image.repository (required "image.tag is required when image.digest is empty" .Values.image.tag) }}
{{- end }}
{{- end }}
