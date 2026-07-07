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
