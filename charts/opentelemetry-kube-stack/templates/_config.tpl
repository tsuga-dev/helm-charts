{{/*
OpenTelemetry Collector Configuration Helper Templates
*/}}

{{/*
Generate environment variables for OpenTelemetry Collector
*/}}
{{- define "opentelemetry-kube-stack.collectorEnv" -}}
{{- if include "opentelemetry-kube-stack.tsugaEnabled" . }}
- name: TSUGA_OTLP_ENDPOINT
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_OTLP_ENDPOINT" "Values" .Values) }}
- name: TSUGA_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "opentelemetry-kube-stack.secretName" . }}
      key: {{ include "opentelemetry-kube-stack.secretKey" (dict "keyName" "TSUGA_API_KEY" "Values" .Values) }}
{{- end }}
- name: MY_POD_IP
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.podIP
- name: NODE_IP
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: status.hostIP
- name: POD_NAME
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: metadata.name
- name: POD_UID
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: metadata.uid
- name: K8S_NODE_NAME
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: spec.nodeName
{{- end }}

{{/*
Shared k8s_attributes `extract` block.

Kept in one place because the agent, cluster receiver and statefulset collector
must enrich identically: otherwise the same pod is described differently
depending on which collector happened to see the telemetry.

Precedence inside the processor is pod > namespace > node, and it never
overwrites an attribute the sender already set, so SDK-provided values always
win over anything derived here.

Context: dict "extraLabelMapping" <list> "extraAnnotationsMapping" <list>
*/}}
{{- define "opentelemetry-kube-stack.k8sAttributesExtract" -}}
metadata:
  # Workload and pod identity.
  - k8s.namespace.name
  - k8s.deployment.name
  - k8s.replicaset.name
  - k8s.statefulset.name
  - k8s.daemonset.name
  - k8s.cronjob.name
  - k8s.job.name
  - k8s.node.name
  - k8s.node.uid
  - k8s.cluster.uid
  - k8s.pod.name
  - k8s.pod.uid
  - k8s.pod.start_time
  # Deliberately not extracted: k8s.pod.ip, k8s.pod.hostname, container.id and
  # service.instance.id. Each takes a new value on every pod or container
  # restart, or simply restates k8s.pod.name, so they cost a high-cardinality
  # dimension on every datapoint and identify nothing that k8s.pod.name and
  # k8s.pod.uid do not already identify.
  #
  # Container identity. Bounded by the number of images in the cluster, and
  # what makes "did this start with the last deploy?" answerable. Applied when
  # the incoming resource carries k8s.container.name, which filelog sets via
  # the container parser.
  - k8s.container.name
  - container.image.name
  - container.image.tag
  # Computed by the processor from the OpenTelemetry semantic conventions:
  # service.name from the well-known app.kubernetes.io/name label then the
  # workload name, service.version from the image tag. This is what keeps
  # workloads that ship telemetry without a configured service name from
  # landing as "unknown_service".
  - service.namespace
  - service.name
  - service.version
labels:
  # Explicit opt-in. Set these on a pod to override anything computed above.
  - tag_name: service.name
    key: resource.opentelemetry.io/service.name
    from: pod
  - tag_name: service.version
    key: resource.opentelemetry.io/service.version
    from: pod
  - tag_name: env
    key: resource.opentelemetry.io/env
    from: pod
  - tag_name: team
    key: resource.opentelemetry.io/team
    from: pod
  # Ownership is usually declared once per namespace rather than on every pod.
  - tag_name: env
    key: resource.opentelemetry.io/env
    from: namespace
  - tag_name: team
    key: resource.opentelemetry.io/team
    from: namespace
  # Node topology straight from the Kubernetes API: the same attributes the
  # cloud detectors would give us, with no metadata-service calls. Simply
  # absent on clusters that do not set the well-known labels.
  - tag_name: cloud.region
    key: topology.kubernetes.io/region
    from: node
  - tag_name: cloud.availability_zone
    key: topology.kubernetes.io/zone
    from: node
  - tag_name: host.type
    key: node.kubernetes.io/instance-type
    from: node
{{- with .extraLabelMapping }}
{{- toYaml . | nindent 2 }}
{{- end }}
annotations:
  - tag_name: service.name
    key: resource.opentelemetry.io/service.name
    from: pod
  - tag_name: service.version
    key: resource.opentelemetry.io/service.version
    from: pod
  - tag_name: env
    key: resource.opentelemetry.io/env
    from: pod
  - tag_name: team
    key: resource.opentelemetry.io/team
    from: pod
  - tag_name: env
    key: resource.opentelemetry.io/env
    from: namespace
  - tag_name: team
    key: resource.opentelemetry.io/team
    from: namespace
{{- with .extraAnnotationsMapping }}
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Generate Tsuga exporters configuration
*/}}
{{- define "opentelemetry-kube-stack.tsugaExporters" -}}
otlp_http/tsuga:
  endpoint: ${TSUGA_OTLP_ENDPOINT}
  headers:
    Authorization: Bearer ${TSUGA_API_KEY}
  encoding: json
  compression: gzip
{{- end }}

{{/*
Fail the render if a pinned collector image is older than v0.119.0, where the
service::telemetry headers schema switched from map to list. Only images with a
parseable semver tag can be checked; untagged/":latest"/operator-default images
resolve at runtime and cannot be verified here.
*/}}
{{- define "opentelemetry-kube-stack.assertCollectorVersion" -}}
{{- range list .Values.image .Values.statefulset.image .Values.agent.image .Values.cluster.image -}}
{{- if . -}}
{{- $tag := trimPrefix "v" (. | toString | splitList ":" | last) -}}
{{- if regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag -}}
{{- if semverCompare "< 0.119.0" $tag -}}
{{- fail (printf "collector image %q is < v0.119.0; service::telemetry headers require the v0.119+ config schema (list-form headers)" .) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Generate Otel telemetry export
*/}}
{{- define "opentelemetry-kube-stack.otelTelemetry" -}}
{{- include "opentelemetry-kube-stack.assertCollectorVersion" . -}}
resource:
  {{- if .Values.clusterName }}
  k8s.cluster.name: {{ .Values.clusterName }}
  {{- end}}
  service.instance.id: ${POD_UID}
{{- if include "opentelemetry-kube-stack.tsugaEnabled" . }}
metrics:
    readers:
    - periodic:
        exporter:
            otlp:
                protocol: http/protobuf
                headers:
                    - name: Authorization
                      value: Bearer ${TSUGA_API_KEY}
                endpoint: ${TSUGA_OTLP_ENDPOINT}/v1/metrics
{{- end }}
{{- end }}
