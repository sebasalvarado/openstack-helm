{{- define "volume_deployment" -}}
{{- $volume := index . 1 -}}
{{- with index . 0 -}}
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: cinder-volume-{{$volume.name}}
  labels:
    system: openstack
    type: backend
    component: cinder
spec:
  replicas: 1
  revisionHistoryLimit: {{ .Values.pod.lifecycle.upgrades.deployments.revision_history }}
  strategy:
    type: {{ .Values.pod.lifecycle.upgrades.deployments.pod_replacement_strategy }}
    {{ if eq .Values.pod.lifecycle.upgrades.deployments.pod_replacement_strategy "RollingUpdate" }}
    rollingUpdate:
      maxUnavailable: {{ .Values.pod.lifecycle.upgrades.deployments.rolling_update.max_unavailable }}
      maxSurge: {{ .Values.pod.lifecycle.upgrades.deployments.rolling_update.max_surge }}
    {{ end }}
  selector:
    matchLabels:
        name: cinder-{{$volume.name}}
  template:
    metadata:
      labels:
        name: cinder-{{$volume.name}}
{{ tuple . "cinder" (print "volume-" $volume.name) | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
      annotations:
        pod.beta.kubernetes.io/hostname: cinder-volume-{{$volume.name}}
        configmap-etc-hash: {{ include (print .Template.BasePath "/etc-configmap.yaml") . | sha256sum }}
        configmap-volume-hash: {{ tuple . $volume | include "volume_configmap" | sha256sum }}
    spec:
      hostname: cinder-volume-{{$volume.name}}
      containers:
        - name: cinder-volume-{{$volume.name}}
          image: {{.Values.global.image_repository}}/{{.Values.global.image_namespace}}/ubuntu-source-cinder-volume:{{.Values.image_version_cinder_volume | default .Values.image_version | required "Please set cinder.image_version or similar" }}
          imagePullPolicy: IfNotPresent
          command:
            - kubernetes-entrypoint
          env:
            - name: COMMAND
              value: "cinder-volume"
            - name: NAMESPACE
              value: {{ .Release.Namespace }}
            - name: SENTRY_DSN
              value: {{.Values.sentry_dsn | quote}}
{{- if or $volume.python_warnings .Values.python_warnings }}
            - name: PYTHONWARNINGS
              value: {{ or $volume.python_warnings .Values.python_warnings | quote }}
{{- end }}
          volumeMounts:
            - name: etccinder
              mountPath: /etc/cinder
            - name: cinder-etc
              mountPath: /etc/cinder/cinder.conf
              subPath: cinder.conf
              readOnly: true
            - name: cinder-etc
              mountPath: /etc/cinder/policy.json
              subPath: policy.json
              readOnly: true
            - name: cinder-etc
              mountPath: /etc/cinder/logging.ini
              subPath: logging.ini
              readOnly: true
            - name: volume-config
              mountPath: /etc/cinder/cinder-volume.conf
              subPath: cinder-volume.conf
              readOnly: true
      volumes:
        - name: etccinder
          emptyDir: {}
        - name: cinder-etc
          configMap:
            name: cinder-etc
        - name: volume-config
          configMap:
            name:  volume-{{$volume.name}}
{{- end -}}
{{- end -}}
