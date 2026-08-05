# opentelemetry-database-monitoring

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.16.0](https://img.shields.io/badge/AppVersion-1.16.0-informational?style=flat-square)

Database monitoring for the OpenTelemetry Collector. For each database instance you
declare, the chart injects a Collector as a **sidecar into the database Pod**,
provisions a least-privilege monitoring user, and exports metrics over OTLP.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://argoproj.github.io/argo-helm | argo-events | 2.4.22 |

## Supported databases

Every database is disabled by default. Enable the ones you need; they can run side
by side in one release. Each has its own setup section below, which is the place to
start — it covers the version requirements, the privileges the monitoring user
gets, and the metrics collected.

| Database | Values key | Setup |
|----------|-----------|-------|
| PostgreSQL | `postgres` | [PostgreSQL](#postgresql) |

| MongoDB | `mongodb` | [MongoDB](#mongodb) |
All databases export **metrics only**. See [Query collection](#query-collection)
for how per-query data is collected and why.

## How it works

### Sidecar collector

```
┌───────────────────────────────────────────┐
│  Your database Pod                        │
│                                           │
│  ┌─────────────┐   ┌─────────────────┐    │
│  │  database   │   │  OTel Collector │    │
│  │  container  │◄──│    (sidecar)    │    │
│  └─────────────┘   └────────┬────────┘    │
│                              │ OTLP/gRPC  │
└──────────────────────────────┼────────────┘
                               ▼
                     Node IP :4317
                 (DaemonSet collector
                  or any OTLP endpoint)
```

The Collector reaches the database over the Pod's own network namespace, so that
traffic never leaves the Pod. For each entry in an engine's `databases` list the
chart creates:

1. **Secret** — holds the auto-generated (or idempotently preserved) password for
   the `otel_monitor` user. When the entry's `namespace` differs from the Helm
   release namespace, the same Secret is replicated into the target namespace so
   the injected sidecar can resolve `secretKeyRef` in the Pod's namespace.
2. **Setup Job** — waits for the database to accept connections, runs the engine's
   setup script, and rotates the `otel_monitor` password to match the Secret. See
   [Argo Events setup](#argo-events-setup) for when and how this Job is created.
3. **OpenTelemetryCollector** (sidecar) — an `opentelemetry.io/v1beta1` CR in the
   **Helm release namespace** that configures the contrib Collector with the
   engine's receivers and exports metrics to `$K8S_NODE_IP:4317`.

Each engine also gets one shared **ConfigMap** carrying its setup script.

### Argo Events setup

When `argoEvents.enabled=true` and `argoEvents.triggerSetupJob=true` (the default),
the chart installs Argo Events and uses it to run the setup Job **after** the OTel
Operator injects the sidecar into a target Pod. This avoids racing database setup
against sidecar startup, and supports deploying monitoring in one namespace while
the database runs in another.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Helm release namespace (e.g. observability)                            │
│                                                                         │
│  EventBus ──► EventSource ──► NATS ──► Sensor ──► Setup Job           │
│                  │                              │                       │
│  OpenTelemetryCollector CR ◄─────────────────────┘ (same release ns)   │
│  Monitor Secret (for Job)                                               │
│  ConfigMap (setup script)                                               │
│  Argo Events controller (argo-events subchart)                          │
└─────────────────────────────────────────────────────────────────────────┘
         ▲                                    │
         │ cross-namespace inject             │ cross-namespace pod watch
         │ annotation                         │ (RBAC in target namespace)
         │                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Target namespace (e.g. demo)                                           │
│                                                                         │
│  database Pod  +  injected OTel sidecar                                 │
│  Monitor Secret (replica for sidecar secretKeyRef)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

The flow for each database entry:

1. **EventBus** — NATS-backed bus in the release namespace
   (`argoEvents.eventBusName`, default `default`).
2. **EventSource** — watches Pod `ADD` events in the target namespace(s). Uses
   `filter.afterStart: true`, so only Pods created **after** the EventSource starts
   trigger events; existing Pods are ignored. It watches the union of the target
   namespaces of every enabled database.
3. **Sensor** (one per database entry) — subscribes to the EventSource and filters
   on the `sidecar.opentelemetry.io/inject` annotation
   (`argoEvents.sidecarInjectAnnotation`). When the annotation matches the expected
   value, it creates the setup Job in the release namespace.
4. **Setup Job** — the same setup as the Helm-hook path; connects using cluster DNS
   (`<host>.<namespace>.svc.cluster.local`) when the database runs in another
   namespace.

When `argoEvents.enabled=false`, or `argoEvents.triggerSetupJob=false`, the setup
Job is created directly as a Helm `post-install` / `post-upgrade` hook instead.

#### Sidecar inject annotation

The OTel Operator must inject the sidecar before the Sensor fires. Annotate the
target Pod (or its controller template) with `sidecar.opentelemetry.io/inject`:

| Scenario | Expected annotation value |
|----------|---------------------------|
| Database in the same namespace as the Helm release | the entry's `sidecar-name` |
| Database in a different namespace | `<releaseNamespace>/<sidecar-name>` (e.g. `observability/postgres-dbm-sidecar`) |

The Sensor filter is derived automatically from each entry's `namespace` and
`sidecar-name`. The `OpenTelemetryCollector` CR always lives in the release
namespace; cross-namespace injection is driven by the annotation prefix.

#### Cross-namespace example

Install monitoring in `observability`, targeting a database in `demo`. The example
uses PostgreSQL; the shape is identical for every engine.

```yaml
# values.yaml for: helm install dbm … -n observability
postgres:
  enabled: true
  databases:
    - name: postgresql
      namespace: demo
      sidecar-name: postgres-dbm-sidecar
      host: postgresql
      user: root
      pwd: otel
      port: 5432

argoEvents:
  enabled: true
  triggerSetupJob: true
```

On the database Pod (in `demo`):

```yaml
podAnnotations:
  sidecar.opentelemetry.io/inject: "observability/postgres-dbm-sidecar"
```

After install, restart the Pod so the EventSource emits a fresh `ADD` event:

```bash
kubectl delete pod -n demo -l app.kubernetes.io/name=postgresql
kubectl get jobs -n observability -l app.kubernetes.io/component=db-monitoring-setup -w
```

#### Multiple databases

Add more entries to an engine's `databases` list, or enable several engines at
once. Every entry gets its own sidecar CR, monitor Secret, and setup Job, and each
needs a distinct `sidecar-name`. The Argo Events plumbing (EventBus, EventSource,
RBAC) is shared across all of them.

#### Disabling Argo Events

```yaml
argoEvents:
  enabled: false          # do not install the controller or EventBus/EventSource/Sensor
  triggerSetupJob: false  # use Helm hook Jobs even when argoEvents.enabled=true
```

Argo Events CRDs are bundled under `crds/` and installed before other chart
resources. The `argo-events` subchart is gated by `argoEvents.enabled`; its own CRD
install is disabled (`argo-events.crds.install: false`) because this chart ships
the CRDs.

## Prerequisites

- Kubernetes 1.21+
- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
  installed in the cluster. It provides the `OpenTelemetryCollector` CRD and injects
  the sidecars.
- An OTLP endpoint reachable at `$K8S_NODE_IP:4317`, such as a DaemonSet Collector.
- When using Argo Events (`argoEvents.enabled=true`): the Argo Events CRDs, which
  are installed from this chart's `crds/` directory on first install.
- Per-database version and privilege requirements are listed in each database's
  setup section.

## Installation

```bash
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
helm repo update

helm install db-monitoring tsuga-charts/opentelemetry-database-monitoring \
  --set postgres.enabled=true \
  --set postgres.databases[0].name=postgresql \
  --set postgres.databases[0].host=postgresql \
  --set postgres.databases[0].user=root \
  --set postgres.databases[0].pwd=<admin-password>
```

Install into the namespace where you want the sidecar CRs, EventBus, and setup Jobs
to live. Set the entry's `namespace` when the database runs elsewhere.

## PostgreSQL

Enable with `postgres.enabled=true`.

### Requirements

- PostgreSQL 10 or later, for `pg_stat_progress_vacuum`.
- An `otel` database must already exist on the instance. The setup Job connects to
  it directly (`psql … -d otel`).
- The admin credentials in `postgres.databases[*].user` / `pwd` must be a superuser,
  or a role with `CREATEROLE` and `CREATEDB`.

### Setup

The setup Job runs `assets/pg-monitoring-setup.sql` idempotently. It:

1. Creates the `otel_monitor` user and grants it `pg_monitor` plus `SELECT` on
   `pg_stat_database`.
2. Enables the `pg_stat_statements` extension.
3. Creates the `otel` schema and grants `USAGE` to `otel_monitor`.
4. Installs the stored functions below, all `STABLE` and safe to re-run.
5. Grants `EXECUTE` on all `otel` functions to `otel_monitor`.
6. Rotates the `otel_monitor` password to match the Secret.

| Function | Description |
|----------|-------------|
| `otel.pg_table_stats()` | Vacuum/analyze ages, autovacuum counts, rows modified since last analyze. Top 50 tables by `n_mod_since_analyze`. |
| `otel.pg_bloat()` | Table bloat ratio and wasted bytes using the standard check_postgres algorithm. Top 20 tables by wasted bytes. |
| `otel.pg_connections()` | Connection count and max state age per database per connection state. |
| `otel.pg_lock_counts()` | Lock counts by type, mode, and granted status. |
| `otel.pg_blocking_queries()` | Count of queries currently waiting on a lock. |
| `otel.pg_idle_in_transaction()` | Idle-in-transaction connection count and max age per database. |
| `otel.pg_replication_slots()` | Replication slot lag in bytes per slot. |
| `otel.pg_wal()` | WAL segment file count and total WAL directory size. |
| `otel.pg_vacuum_progress()` | Active vacuum operations with phase and block progress. |
| `otel.pg_top_queries()` | Top queries by call count from `pg_stat_statements`. |

### Metrics

The `postgresql` receiver polls the PostgreSQL statistics views directly, with 20
default-disabled metrics additionally enabled by this chart.

| Metric | Unit | Description |
|--------|------|-------------|
| `postgresql.bgwriter.buffers.allocated` | `{buffer}` | Buffers allocated by bgwriter |
| `postgresql.bgwriter.buffers.writes` | `{buffer}` | Buffers written by bgwriter |
| `postgresql.bgwriter.checkpoint.count` | `{checkpoint}` | Checkpoint count |
| `postgresql.bgwriter.duration` | `ms` | Checkpoint write/sync duration |
| `postgresql.bgwriter.maxwritten` | `1` | Times bgwriter stopped a round due to too many buffers written |
| `postgresql.blks_hit` | `{hit}` | Buffer cache hits |
| `postgresql.blks_read` | `{read}` | Disk blocks read |
| `postgresql.connection.max` | `{connection}` | Max connections configured |
| `postgresql.database.locks` | `{lock}` | Database lock counts |
| `postgresql.deadlocks` | `{deadlock}` | Deadlocks detected |
| `postgresql.replication.data_delay` | `By` | Replication data delay |
| `postgresql.sequential_scans` | `{scan}` | Sequential scans |
| `postgresql.temp_files` | `{file}` | Temp files created |
| `postgresql.tup_deleted` / `tup_fetched` / `tup_inserted` / `tup_returned` / `tup_updated` | `{tuple}` | Row operation counters |
| `postgresql.wal.age` | `s` | WAL archiver age |
| `postgresql.wal.lag` | `s` | Replication WAL lag |

The `sqlquery` receivers read the stored functions installed above:

| Receiver | Interval | Metrics |
|----------|----------|---------|
| `sqlquery/postgresql_top_queries` | default | `postgresql.query.calls`, `.rows`, `.exec_time`, `.plan_time`, `.blocks.shared.*`, `.blocks.temp.*` — attributed by `db.namespace`, `db.user.name`, `server.address`, `db.query.text`, `db.version` |
| `sqlquery/pg_table_stats` | 5 min | `postgresql.table.vacuum.age`, `.autovacuum.age`, `.analyze.age`, `.autoanalyze.age`, `.autovacuum.count`, `.analyze.count`, `.autoanalyze.count`, `.rows.modified.since.analyze` |
| `sqlquery/pg_bloat` | 1 hour | `postgresql.table.bloat.ratio`, `postgresql.table.bloat.bytes` |
| `sqlquery/pg_connections` | 30 s | `postgresql.backends`, `postgresql.backends.age` |
| `sqlquery/pg_locks` | 30 s | `postgresql.lock.count`, `postgresql.lock.blocking_queries`, `postgresql.connection.idle_in_transaction`, `postgresql.connection.idle_in_transaction.age` |
| `sqlquery/pg_replication` | 30 s | `postgresql.replication.slot.lag` |
| `sqlquery/pg_wal` | 60 s | `postgresql.wal.file_count`, `postgresql.wal.bytes` |
| `sqlquery/pg_vacuum_progress` | 60 s | `postgresql.vacuum.heap_blks_total`, `.heap_blks_scanned`, `.heap_blks_vacuumed`, `postgresql.vacuum.age` |

### Example

See `examples/pg-single-db/` and `examples/pg-multiple-db/`.

```yaml
postgres:
  enabled: true
  databases:
    - name: postgresql
      sidecar-name: postgres-dbm-sidecar
      user: root
      pwd: otel
      port: 5432
      host: postgresql
```

Annotate the PostgreSQL Pod with
`sidecar.opentelemetry.io/inject: postgres-dbm-sidecar`.

## MongoDB

Enable with `mongodb.enabled=true`.

### Requirements

- MongoDB 4.4 or later.
- The admin credentials in `mongodb.databases[*].user` / `pwd` must hold the
  `userAdmin` role on the `admin` database, or `root`.

### Setup

The setup Job runs `assets/mongodb-monitoring-setup.js` with `mongosh`,
idempotently. It creates the `otel_monitor` user in the `admin` database with the
built-in `clusterMonitor` role, which is the role MongoDB documents for a
least-privilege monitoring user and the role the receiver requires to collect
metrics. On re-run it updates the password in place, so a rotated monitor Secret
converges instead of failing because the user already exists.

There are no helper collections or views to install: the receiver reads the
`serverStatus`, `dbStats`, and index stats commands directly. The generated password
is passed to the script through `OTEL_MONITOR_PASSWORD` in the environment rather
than on the command line, and the script exits non-zero if that variable is unset.

### Metrics

The `mongodb` receiver runs at a 30 s interval and reports 36 metrics: cache
operations, collection, database, index and object counts, cursor counts and
timeouts, connection count, data, index and storage sizes, memory usage, document
and operation counts, operation time, global lock time, network I/O and request
count, and session count, plus 15 default-disabled metrics enabled by this chart
(active reads and writes, the per-second command, delete, getmore, insert, query and
update rates, health, lock acquire count, operation latency, replicated operation
count, page faults, uptime, and WiredTiger cache reads).

Two settings are worth knowing about:

- **`hosts`** takes a list of endpoint objects. This chart sets the single endpoint
  of the Pod the sidecar runs in.
- **`direct_connection: true`** makes each sidecar scrape only the `mongod` beside
  it. With discovery enabled the receiver runs `replSetGetStatus` and connects out
  to secondaries; because this chart injects one sidecar per Pod, every member is
  already scraped by its own Collector, so discovery would report secondaries more
  than once. `replSetGetStatus` is also not valid on a standalone server or through
  `mongos`, where it logs a warning on each scrape. Set it to `false` by overriding
  the asset config if you want one Collector to scrape a whole replica set.

The following metrics are deliberately left disabled, each verified to report no
data on MongoDB 7 with the WiredTiger storage engine:

| Metric | Reason |
|--------|--------|
| `mongodb.extent.count` | Enabled upstream by default, but only reported by servers older than 4.4 using the mmapv1 storage engine. |
| `mongodb.flushes.rate` | Fails the scrape with `could not find key for metric`. |
| `mongodb.lock.acquire.time`, `.wait_count`, `mongodb.lock.deadlock.count` | Reported only while locks are contended. |
| `mongodb.repl_*_per_sec` | Reported only by replica set members. |

This receiver offers query samples as log records only, and has no top-query
support, so there are no per-query metrics for MongoDB.

### Topologies

For a sharded cluster, annotate the `mongos` Pods. For a replica set, annotate each
member Pod; every member then reports its own metrics, distinguished by the
`server.address` resource attribute.

### Example

See `examples/mongodb-single-db/`.

```yaml
mongodb:
  enabled: true
  databases:
    - name: mongodb
      sidecar-name: mongodb-dbm-sidecar
      user: root
      pwd: otel
      port: 27017
      host: mongodb
```

Annotate the MongoDB Pod with `sidecar.opentelemetry.io/inject: mongodb-dbm-sidecar`.

## Query collection

Several database receivers can report per-query data through a native
`top_query_collection` or `query_sample_collection` block. Those blocks emit **log
records** — the `db.server.top_query` and `db.server.query_sample` events — and
that logs signal is at **Development** stability. This chart exports metrics only,
so where per-query data is available it is collected with the `sqlquery` receiver
against a view or function installed by the setup script.

| Database | Per-query metrics | Mechanism |
|----------|------------------|-----------|
| PostgreSQL | yes | `sqlquery` over `otel.pg_top_queries()` |

| MongoDB | no | the receiver offers query samples as log records only, and has no top-query support |
The native blocks are functional, so this is a choice about signal type rather than
a workaround. To use the native events instead, enable them on the receiver and add
a `logs` pipeline by overriding the engine's asset config. Do not run both: they
report the same data twice.

## Security notes

- The admin credentials (`user` / `pwd`) are used only by the setup Job. They are
  interpolated into the Job spec, so they are readable by anyone who can read Jobs
  in the release namespace, and are not written to a Secret.
- The sidecar uses the auto-generated `otel_monitor` password from the Secret. With
  Helm hook Jobs the password is rotated on every `helm upgrade`; with Argo Events,
  rotation happens each time a new setup Job completes.
- The Secret is created with `lookup` to preserve the existing password across
  upgrades. A new random 24-character password is generated only on first install.
- The `otel_monitor` user is read-only on every database and has no write access to
  application data. The exact grants are listed in each database's setup section.
- **Why TLS is off between the sidecar and the database.** The Collector runs as a
  sidecar *inside the database Pod*, so it reaches the server over the Pod's own
  network namespace and that traffic never leaves the Pod. That is the assumption
  behind disabling TLS on the receivers and their `sqlquery` datasources. **If you
  repoint these configs at a database outside the Pod, the assumption no longer
  holds** — configure TLS first by overriding the engine's asset config.
- The export hop to `$K8S_NODE_IP:4317` also runs without TLS. Unlike the database
  hop this one does leave the Pod, so it relies on the node-local Collector being
  trusted.
- The Collector image is pinned to a concrete tag. An untagged image resolves to
  `:latest`, which forces `imagePullPolicy: Always` and lets the Collector version
  change under the configuration in `assets/`.

## Upgrading

**Without Argo Events** (`argoEvents.enabled=false` or
`argoEvents.triggerSetupJob=false`): the setup Job runs on both `post-install` and
`post-upgrade` Helm hooks with a `before-hook-creation` deletion policy, so it
re-runs on every `helm upgrade`.

**With Argo Events** (default): the setup Job is created by a Sensor when a new
target Pod is added with the correct inject annotation. Upgrading the chart updates
EventSource and Sensor configuration but does not re-run setup on existing Pods.
Restart the target Pod after upgrade if you need setup to run again.

All setup scripts are idempotent, and password rotation uses the existing Secret
value.

## Troubleshooting

**Authentication errors in the sidecar right after a Pod starts**

Expected, and self-correcting. With Argo Events driving setup, the sequence is: the
Pod starts, the operator injects the sidecar, the Sensor sees the Pod and creates
the setup Job, and the Job creates the `otel_monitor` user. The sidecar therefore
begins scraping a few seconds before that user exists, and logs one scrape failure
per interval until it does.

Compare the error timestamp against the Job's completion time before treating it as
a real failure:

```bash
kubectl -n <release-namespace> get job -l app.kubernetes.io/component=db-monitoring-setup \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.completionTime}{"\n"}{end}'
```

Errors older than the completion time are the startup race. Errors newer than it
are a real problem: check that the Job succeeded, and that the monitor Secret in
the database's namespace matches the one in the release namespace.

**Setup Job never created (Argo Events enabled)**

The EventSource only reports Pods created after it starts (`filter.afterStart:
true`). Restart the database Pod:

```bash
kubectl delete pod -n <target-namespace> -l <your-database-selector>
```

Then confirm the annotation on the Pod matches the value the Sensor expects — see
[Sidecar inject annotation](#sidecar-inject-annotation).

**Sidecar not injected**

Check that the OpenTelemetry Operator is running, that the
`OpenTelemetryCollector` CR exists in the release namespace, and that the Pod
annotation carries the `<releaseNamespace>/` prefix when the database runs in
another namespace:

```bash
kubectl get opentelemetrycollectors -A
kubectl -n <target-namespace> get pod <pod> -o jsonpath='{.spec.initContainers[*].name}'
```

The operator injects the Collector as a native sidecar, so it appears under
`initContainers` with `restartPolicy: Always` rather than under `containers`.

**Setup Job failing**

```bash
kubectl -n <release-namespace> logs job/<db-name>-<engine>-monitoring-setup
```

The Job waits for the database to accept connections before running setup, so a Job
stuck in that loop means the `host` and `port` in values do not reach the database.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| argo-events.crds.install | bool | false | Let the Argo Events subchart install its own CRDs. Keep this false: the CRDs are shipped in this chart's crds/ directory. |
| argo-events.enabled | bool | true | Install the bundled Argo Events controller subchart. |
| argoEvents.enabled | bool | true | Watch for Pods carrying the sidecar inject annotation and react to them. Also gates the EventBus, EventSource, Sensors, and their RBAC. |
| argoEvents.eventBus.auth | string | `"none"` | Authentication strategy for the native NATS EventBus. |
| argoEvents.eventBus.create | bool | true | Create the EventBus. Argo Events requires one in the namespace and the controller subchart does not create it. |
| argoEvents.eventBus.replicas | int | `1` | Number of NATS replicas in the native EventBus. |
| argoEvents.eventBusName | string | `"default"` | Name of the EventBus the EventSource and Sensors connect to. |
| argoEvents.eventSource.name | string | "" | Name of the EventSource. Defaults to `<fullname>-pod-created` when empty. |
| argoEvents.eventSource.serviceAccount.create | bool | true | Create the EventSource ServiceAccount and its Pod-watch RBAC. |
| argoEvents.eventSource.serviceAccount.name | string | "" | Name of the EventSource ServiceAccount. Defaults to `<fullname>-argo-eventsource` when empty. |
| argoEvents.eventSource.watchNamespace | string | "" | Single namespace to watch for Pod events. When empty, the chart watches the union of the target namespaces of every enabled engine. |
| argoEvents.job.generateNameSuffix | string | `"setup-"` | Suffix appended to the generateName of Sensor-created setup Jobs. |
| argoEvents.sensor.serviceAccount.create | bool | true | Create the Sensor ServiceAccount and its Job-create RBAC. |
| argoEvents.sensor.serviceAccount.name | string | "" | Name of the Sensor ServiceAccount. Defaults to `<fullname>-argo-sensor` when empty. |
| argoEvents.sidecarInjectAnnotation | string | `"sidecar.opentelemetry.io/inject"` | Pod annotation key the OpenTelemetry Operator reads to inject a sidecar. The Sensors filter incoming Pod events on this key. |
| argoEvents.triggerSetupJob | bool | true | Create each setup Job from an Argo Events Sensor when a target Pod appears, instead of from a Helm post-install/post-upgrade hook. Running setup after the operator has injected the sidecar avoids racing database setup against sidecar startup, and allows the release to live in a different namespace from the database. |
| mongodb.databases | list | `[{"host":"","name":"mongodb","namespace":"","port":27017,"pwd":"","sidecar-name":"mongodb-dbm-sidecar","user":""}]` | MongoDB instances to monitor. Each entry produces its own sidecar collector, monitor secret, and setup Job. |
| mongodb.databases[0] | object | `{"host":"","name":"mongodb","namespace":"","port":27017,"pwd":"","sidecar-name":"mongodb-dbm-sidecar","user":""}` | Name for this instance. Used as the prefix of the monitor secret and setup Job names, and set as the `opentelemetry-database-monitoring/database` label on every resource. |
| mongodb.databases[0].host | string | "" | Host the setup Job connects to, normally the MongoDB Service name. A value containing a dot is used as-is; otherwise, when the instance runs in another namespace, it is expanded to `<host>.<namespace>.svc.cluster.local`. |
| mongodb.databases[0].namespace | string | "" | Namespace where the annotated MongoDB Pod runs. Replicates the monitor secret into that namespace and sets the expected inject annotation to `<releaseNamespace>/<sidecar-name>` when it differs from the release namespace. Empty means the release namespace. |
| mongodb.databases[0].port | int | `27017` | Port the setup Job connects to. The sidecar's receiver port is fixed at 27017 in assets/mongodb-monitoring-config.yaml; override that asset to change the port the collector uses. |
| mongodb.databases[0].pwd | string | "" | Password for the administrative user. Interpolated into the setup Job spec, so it is readable by anyone who can read Jobs in the release namespace. It is not written to a secret. |
| mongodb.databases[0].sidecar-name | string | `"mongodb-dbm-sidecar"` | Name of the OpenTelemetryCollector resource for this instance. This is the value the target Pod's `sidecar.opentelemetry.io/inject` annotation must carry for the operator to inject the sidecar. |
| mongodb.databases[0].user | string | "" | Administrative user the setup Job authenticates as against the admin database. Needs the userAdmin role on admin, or root. |
| mongodb.enabled | bool | false | Deploy MongoDB monitoring: the injected sidecar collector, the monitor credentials secret, the setup ConfigMap, and the setup Job. |
| mongodb.image | string | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.157.0"` | Collector image for the injected sidecar. |
| mongodb.setupImage | string | `"mongo:7"` | Image for the setup Job. Must provide the `mongosh` client on PATH. |
| postgres.databases | list | `[{"host":"","name":"postgresql","namespace":"","port":5432,"pwd":"","sidecar-name":"postgres-dbm-sidecar","user":""}]` | PostgreSQL instances to monitor. Each entry produces its own sidecar collector, monitor secret, and setup Job. |
| postgres.databases[0] | object | `{"host":"","name":"postgresql","namespace":"","port":5432,"pwd":"","sidecar-name":"postgres-dbm-sidecar","user":""}` | Name for this instance. Used as the prefix of the monitor secret and setup Job names, and set as the `opentelemetry-database-monitoring/database` label on every resource. |
| postgres.databases[0].host | string | "" | Host the setup Job connects to, normally the PostgreSQL Service name. A value containing a dot is used as-is; otherwise, when the instance runs in another namespace, it is expanded to `<host>.<namespace>.svc.cluster.local`. |
| postgres.databases[0].namespace | string | "" | Namespace where the annotated PostgreSQL Pod runs. Replicates the monitor secret into that namespace and sets the expected inject annotation to `<releaseNamespace>/<sidecar-name>` when it differs from the release namespace. Empty means the release namespace. |
| postgres.databases[0].port | int | `5432` | Port the setup Job connects to. The sidecar's receiver port is fixed at 5432 in assets/pg-monitoring-config.yaml; override that asset to change the port the collector uses. |
| postgres.databases[0].pwd | string | "" | Password for the administrative user. Interpolated into the setup Job spec, so it is readable by anyone who can read Jobs in the release namespace. It is not written to a secret. |
| postgres.databases[0].sidecar-name | string | `"postgres-dbm-sidecar"` | Name of the OpenTelemetryCollector resource for this instance. This is the value the target Pod's `sidecar.opentelemetry.io/inject` annotation must carry for the operator to inject the sidecar. |
| postgres.databases[0].user | string | "" | Administrative user the setup Job connects as. Needs to be a superuser, or a role with CREATEROLE and CREATEDB. |
| postgres.enabled | bool | false | Deploy PostgreSQL monitoring: the injected sidecar collector, the monitor credentials secret, the setup ConfigMap, and the setup Job. |
| postgres.image | string | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.157.0"` | Collector image for the injected sidecar. |
