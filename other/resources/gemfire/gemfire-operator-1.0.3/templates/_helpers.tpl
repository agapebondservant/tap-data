{{- define "imagePullSecret" }}
    {{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.registry.server (printf "%s:%s" .Values.registry.username .Values.registry.password | b64enc) | b64enc }}
{{- end }}
