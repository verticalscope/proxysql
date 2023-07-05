{{- define "proxysql.pod" -}}
metadata:
{{- with .Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
{{- end }}
  labels:
    {{- include "proxysql.selectorLabels" . | nindent 4 }}
spec:
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "proxysql.serviceAccountName" . }}
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 4 }}
  containers:
    - name: {{ .Chart.Name }}
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      command:
        - proxysql
        - "-f"
        - "--idle-threads"
        - "-D"
        - "/var/lib/proxysql"
        - "--reload"
      ports:
        - name: mysql
          containerPort: {{ .Values.proxysql.mysql.port }}
          protocol: TCP
        - name: proxysql
          containerPort: {{ .Values.proxysql.port }}
          protocol: TCP
        - name: metrics
          containerPort: 6070
          protocol: TCP
      livenessProbe:
        tcpSocket:
          port: proxysql
      readinessProbe:
        tcpSocket:
          port: proxysql
      volumeMounts:
        - name: proxysql-config
          mountPath: /etc/proxysql.cnf
          subPath: proxysql.cnf
          readOnly: true
        - name: proxysql-tmp
          mountPath: /tmp/proxysql
      {{- if and .Values.proxysql.cluster.enabled .Values.proxysql.cluster.claim.enabled }}
        - name: {{ include "proxysql.fullname" . }}-pv
          mountPath: /var/lib/proxysql
      {{- end }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
    - name: {{ .Chart.Name }}-user-sync-sidecar
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      env:
        - name: CONSUL_TOKEN
          valueFrom:
            secretKeyRef:
              name: consul-token-readonly
              key: token
      command: [ "/bin/bash", "/sync-proxysql-users.sh" ]
      volumeMounts:
        - name: proxysql-tmp
          mountPath: /tmp/proxysql
        - name: proxysql-user-sync-script
          mountPath: /sync-proxysql-users.sh
          subPath: sync-proxysql-users.sh
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
  volumes:
    - name: proxysql-config
      configMap:
        name: {{ .Values.proxysql.configmap | default (include "proxysql.fullname" .) }}
    - name: proxysql-tmp
      emptyDir:
        sizeLimit: 50Mi
    - name: proxysql-user-sync-script
      configMap:
        name: proxysql-user-sync-script
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
