{{/*
Render the PostgreSQL monitoring setup Job.

Context:
  .root             - root Helm context
  .db               - database entry from postgres.databases
  .useName          - bool: use metadata.name
  .useGenerateName  - bool: use metadata.generateName
*/}}
{{- define "opentelemetry-database-monitoring.setupJob" -}}
{{- $root := .root -}}
{{- $db := .db -}}
{{- $dbHost := include "opentelemetry-database-monitoring.databaseHost" (dict "root" $root "db" $db) -}}
apiVersion: batch/v1
kind: Job
metadata:
  {{- if .useGenerateName }}
  generateName: {{ $db.name }}-postgresql-monitoring-setup-
  {{- else }}
  name: {{ $db.name }}-postgresql-monitoring-setup
  {{- end }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "opentelemetry-database-monitoring.labels" $root | nindent 4 }}
    app.kubernetes.io/component: db-monitoring-setup
    opentelemetry-database-monitoring/database: {{ $db.name }}
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        {{- include "opentelemetry-database-monitoring.selectorLabels" $root | nindent 8 }}
        app.kubernetes.io/component: db-monitoring-setup
        opentelemetry-database-monitoring/database: {{ $db.name }}
    spec:
      restartPolicy: OnFailure
      containers:
        - name: setup
          image: postgres:17
          command:
            - /bin/sh
            - -c
            - |
              set -e
              until pg_isready -h {{ $dbHost }} -p {{ $db.port }} -U {{ $db.user }}; do sleep 2; done
              PGPASSWORD={{ $db.pwd }} psql -v ON_ERROR_STOP=1 -h {{ $dbHost }} -p {{ $db.port }} -U {{ $db.user }} -d otel -f /scripts/monitoring-setup.sql
              PGPASSWORD={{ $db.pwd }} psql -v ON_ERROR_STOP=1 -h {{ $dbHost }} -p {{ $db.port }} -U {{ $db.user }} -d otel -c "ALTER USER otel_monitor WITH PASSWORD '$OTEL_MONITOR_PASSWORD'"
              # Confirm the monitoring role is actually usable on the endpoint we reached;
              # fail (and let backoffLimit retry) if the setup did not land where the collector connects.
              PGPASSWORD="$OTEL_MONITOR_PASSWORD" psql -v ON_ERROR_STOP=1 -h {{ $dbHost }} -p {{ $db.port }} -U otel_monitor -d otel -c "SELECT 1" > /dev/null
          env:
            - name: OTEL_MONITOR_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "opentelemetry-database-monitoring.monitorSecretName" $db }}
                  key: password
          volumeMounts:
            - name: monitoring-setup
              mountPath: /scripts
      volumes:
        - name: monitoring-setup
          configMap:
            name: postgresql-monitoring-setup
{{- end }}

{{/*
Render the MySQL monitoring setup Job.

Context:
  .root             - root Helm context
  .db               - database entry from mysql.databases
  .useName          - bool: use metadata.name
  .useGenerateName  - bool: use metadata.generateName
  .helmHook         - bool: add Helm post-install/post-upgrade hook annotations.
                      Set when Helm owns the Job; leave unset when the Argo
                      Events sensor creates it, which is not a Helm operation.
*/}}
{{- define "opentelemetry-database-monitoring.mysqlSetupJob" -}}
{{- $root := .root -}}
{{- $db := .db -}}
{{- $dbHost := include "opentelemetry-database-monitoring.databaseHost" (dict "root" $root "db" $db) -}}
apiVersion: batch/v1
kind: Job
metadata:
  {{- if .useGenerateName }}
  generateName: {{ $db.name }}-mysql-monitoring-setup-
  {{- else }}
  name: {{ $db.name }}-mysql-monitoring-setup
  {{- end }}
  {{- if .helmHook }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": before-hook-creation
  {{- end }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "opentelemetry-database-monitoring.labels" $root | nindent 4 }}
    app.kubernetes.io/component: db-monitoring-setup
    opentelemetry-database-monitoring/database: {{ $db.name }}
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        {{- include "opentelemetry-database-monitoring.selectorLabels" $root | nindent 8 }}
        app.kubernetes.io/component: db-monitoring-setup
        opentelemetry-database-monitoring/database: {{ $db.name }}
    spec:
      restartPolicy: OnFailure
      containers:
        - name: setup
          image: {{ $root.Values.mysql.setupImage | default "mysql:8.4" }}
          command:
            - /bin/sh
            - -c
            - |
              set -e
              until mysqladmin ping -h {{ $dbHost }} -P {{ $db.port }} -u {{ $db.user }} --silent; do sleep 2; done
              mysql -h {{ $dbHost }} -P {{ $db.port }} -u {{ $db.user }} < /scripts/monitoring-setup.sql
              mysql -h {{ $dbHost }} -P {{ $db.port }} -u {{ $db.user }} \
                -e "ALTER USER 'otel_monitor'@'%' IDENTIFIED BY '$OTEL_MONITOR_PASSWORD'"
              # Confirm the monitoring role is actually usable on the endpoint we reached,
              # and that it can read the views the collector scrapes. Fail (and let
              # backoffLimit retry) if the setup did not land where the collector connects.
              MYSQL_PWD="$OTEL_MONITOR_PASSWORD" mysql -h {{ $dbHost }} -P {{ $db.port }} -u otel_monitor \
                -e "SELECT 1 FROM otel.mysql_top_queries LIMIT 0" > /dev/null
          env:
            # MYSQL_PWD keeps the admin password out of the container's process list.
            # It is still visible in the Job spec, because it comes from values.
            - name: MYSQL_PWD
              value: {{ $db.pwd | quote }}
            - name: OTEL_MONITOR_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "opentelemetry-database-monitoring.mysqlMonitorSecretName" $db }}
                  key: password
          volumeMounts:
            - name: monitoring-setup
              mountPath: /scripts
      volumes:
        - name: monitoring-setup
          configMap:
            name: mysql-monitoring-setup
{{- end }}
