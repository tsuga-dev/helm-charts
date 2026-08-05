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
Render the Microsoft SQL Server monitoring setup Job.

Context:
  .root             - root Helm context
  .db               - database entry from sqlserver.databases
  .useName          - bool: use metadata.name
  .useGenerateName  - bool: use metadata.generateName
  .helmHook         - bool: add Helm post-install/post-upgrade hook annotations.
                      Set when Helm owns the Job; leave unset when the Argo
                      Events sensor creates it, which is not a Helm operation.
*/}}
{{- define "opentelemetry-database-monitoring.sqlserverSetupJob" -}}
{{- $root := .root -}}
{{- $db := .db -}}
{{- $dbHost := include "opentelemetry-database-monitoring.databaseHost" (dict "root" $root "db" $db) -}}
apiVersion: batch/v1
kind: Job
metadata:
  {{- if .useGenerateName }}
  generateName: {{ $db.name }}-sqlserver-monitoring-setup-
  {{- else }}
  name: {{ $db.name }}-sqlserver-monitoring-setup
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
          image: {{ $root.Values.sqlserver.setupImage | default "mcr.microsoft.com/mssql-tools:latest" }}
          command:
            - /bin/sh
            - -c
            - |
              set -e
              SQLCMD=/opt/mssql-tools/bin/sqlcmd
              # -b makes sqlcmd exit non-zero on a SQL error, so `set -e` can act on it.
              until $SQLCMD -b -S {{ $dbHost }},{{ $db.port }} -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
                -Q "SELECT 1" > /dev/null 2>&1; do sleep 2; done
              $SQLCMD -b -S {{ $dbHost }},{{ $db.port }} -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
                -i /scripts/monitoring-setup.sql
              $SQLCMD -b -S {{ $dbHost }},{{ $db.port }} -U "$ADMIN_USER" -P "$ADMIN_PASSWORD" \
                -Q "ALTER LOGIN otel_monitor WITH PASSWORD = N'$OTEL_MONITOR_PASSWORD'"
              # Confirm the monitor login is usable on the endpoint the collector
              # connects to, and that it can read the views the sidecar scrapes.
              # Failing here lets backoffLimit retry rather than leaving a sidecar
              # that cannot authenticate.
              $SQLCMD -b -S {{ $dbHost }},{{ $db.port }} -U otel_monitor -P "$OTEL_MONITOR_PASSWORD" \
                -d otel -Q "SELECT TOP 0 1 FROM dbo.sqlserver_top_queries" > /dev/null
          env:
            - name: ADMIN_USER
              value: {{ $db.user | quote }}
            # Passed as an env var so the admin password stays off the container's
            # process list. It is still visible in the Job spec, because it comes
            # from values.
            - name: ADMIN_PASSWORD
              value: {{ $db.pwd | quote }}
            - name: OTEL_MONITOR_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "opentelemetry-database-monitoring.sqlserverMonitorSecretName" $db }}
                  key: password
          volumeMounts:
            - name: monitoring-setup
              mountPath: /scripts
      volumes:
        - name: monitoring-setup
          configMap:
            name: sqlserver-monitoring-setup
{{- end }}
