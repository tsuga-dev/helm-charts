# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2026-11-13

### Added

- The agent, gateway and scraper extract `k8s.replicaset.name` by default, as the `opentelemetry-kube-stack` chart does. Faulty-deployment detection keys on it to tell a Deployment's revisions apart. It adds no series, since a pod keeps one ReplicaSet for its whole life. A `k8sAttributes.metadata` override still replaces the whole list, so add it there if you set one.

## [0.6.0] - 2026-11-12

### Added

- `TsugaCollectorConfig` `extraRules` on `agent`, `gateway`, `prometheus` and `profiling`, appended to that collector's ClusterRole for components added through `extraReceivers` or `extraExtensions`. The operator must hold any rule it grants: bind rules beyond its ClusterRole to the operator's ServiceAccount, or the reconcile fails with `ApplyFailed`. See [Cluster access](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/kubernetes-monitoring/custom-config.md#cluster-access).
- `TsugaPostgresMonitoring` `sslMode: verify-full`, with `spec.tls` to mount a CA bundle and client certificate from a `secret`, `configMap`, `projected` or `csi` volume at `/etc/tsuga/pg-tls`. Without `caFile`, `verify-full` uses the collector's system roots and needs `provisioning.mode: manual`: the setup Job image has no system CA store, so managed mode requires `caFile`. A `keyFile` gets `defaultMode: 0440` when you set none, and `fsGroup` on the collector (10001) and setup Job (999) pods. Secrets mounted through `spec.tls.volume` need the label `observability.tsuga.com/postgres-credentials=true`. `verify-ca` is not supported. See [TLS](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/kubernetes-monitoring/dbm.md#tls).
- `TsugaPostgresMonitoring` `spec.role`, the monitoring role name, default `otel_monitor` and immutable. The operator sets the comment `managed-by: tsuga-operator` on roles it creates and only changes the password of roles that carry it. See [Roles](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/kubernetes-monitoring/dbm.md#roles).
- `TsugaPostgresMonitoring` `spec.passwordSecretRef`, a Secret with a `password` key for a role the operator did not generate a password for. It needs the label `observability.tsuga.com/postgres-credentials=true`. See [Bring your own role and password](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/kubernetes-monitoring/dbm.md#bring-your-own-role-and-password).
- Role conflicts: two resources with the same host, port and role no longer overwrite each other's password. The oldest keeps the role and the others report phase `Error`, reason `RoleConflict`, with no collector and no setup Job.
- `TsugaPostgresMonitoring` `spec.mode: sidecar` runs the PostgreSQL collector as an OpenTelemetry Operator sidecar in the database pod, as the `opentelemetry-database-monitoring` chart did. Annotate the database pod template with `sidecar.opentelemetry.io/inject: <name>-pg`; the `Ready` message names it. The resource must be in the database's namespace. Sidecar mode takes no `tls`, `verify-full`, `nodeSelector` or `tolerations`, sets the security context on the container, and reads the password Secret as optional so it never blocks the database pod. Changing `mode` recreates the collector. The default, `deployment`, is unchanged. Ship this release's TsugaPostgresMonitoring CRD with the image: the old CRD drops `mode` and renders a Deployment. See [Sidecar mode](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/kubernetes-monitoring/dbm.md#sidecar-mode).
- `TsugaPostgresMonitoring` accepts `spec.image`, `spec.resources`, `spec.nodeSelector` and `spec.tolerations` for its collector. Previously the 256Mi memory limit could not be raised for busy servers. See [Configuration](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/reference/configuration.md#postgresql-runtime-defaults).
- `TsugaCollector` runs your own OpenTelemetry collector from a native `OpenTelemetryCollector` spec, rendered as `tsuga-<name>`. The `tsugaExporter`, `selfTelemetry` and `defaultProcessors` toggles (all on by default) add export through the node agent, internal metrics and `memory_limiter`/`batch` without replacing anything the spec defines. See [Custom collectors](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/kubernetes-monitoring/custom-collectors.md).
- `TsugaPostgresMonitoring` accepts `extraExtensions` and `serviceExtensions`, like the agent, gateway and scraper. See [DBM](https://github.com/tsuga-dev/tsuga-operator/blob/v0.6.0/docs/site/kubernetes-monitoring/dbm.md#add-collector-extensions).
- The operator starts without an operation key (`api-token` is optional in `tsuga-credentials`), for collection-only installs. Without one it does not start the Dashboard, Monitor and SLO controllers, so those resources keep their status and finalizers until it restarts with a key.

### Changed

- The `otel` schema and function grants go to `pg_monitor` instead of to the monitoring role.
- Manual setup takes the role name: `psql -v role=<name> -f postgres-setup.sql`.
- The setup Job sets the monitoring password with psql's `\password`, so `pg_stat_statements`, readable by every `pg_monitor` member, holds a hash instead of the password.
- The setup Job fails when the monitoring role cannot use the `otel` schema, for example when another admin owns it, instead of completing with collection broken.
- A role without the `managed-by: tsuga-operator` comment gets `pg_monitor` only when the setup Job can log in as it with the Secret's password and a random wrong password is refused. Before, setup granted `pg_monitor` to any role it named, even when the password check then failed.

### Fixed

- Re-running setup no longer removes EXECUTE on `otel.pg_top_queries` from other monitoring roles on the same server.

### Upgrade notes

- Install the `TsugaCollector` CRD and the manager ClusterRole from this release with the image. Without the CRD the operator starts with the `TsugaCollector` controller disabled; with the CRD but without the RBAC, cache sync fails and the operator exits.
- The setup Job re-runs once per resource after the upgrade, because the setup SQL changed.
- An existing `otel_monitor` without the marker comment is adopted when the setup Job can log in as it with the generated password and a random wrong password is refused. Every setup run makes this check, which logs one failed login per run and may show up in auth-failure alerts.
- A DBA-created role under `trust` or `cert` authentication in `pg_hba.conf` no longer gets `pg_monitor` from setup, and the setup Job now fails with `is not in pg_monitor or cannot use the otel schema`. Grant `pg_monitor` to the role by hand, or switch it to password authentication.
- A setup Job that ran as an admin that does not own the `otel` schema used to complete; it now fails with the same message unless `pg_monitor` already has access to the schema. Run setup once as the admin that owns `otel`, or as a superuser, so the grants go to `pg_monitor`.
- If the generated `<name>-pg-monitor` Secret was re-created, so its password no longer matches the role, run `COMMENT ON ROLE otel_monitor IS 'managed-by: tsuga-operator'` as an admin and let setup run again.
- Two resources on one server that both use the default role: after the upgrade the oldest keeps the role and the other becomes `RoleConflict`. The role likely holds the newer resource's password, so the oldest one's setup cannot prove the role is its own and fails with `ProvisioningFailed`, and neither resource collects. To recover, have a DBA run `COMMENT ON ROLE otel_monitor IS 'managed-by: tsuga-operator'`, then delete the oldest resource's setup Job so it runs again and sets its password. `spec.role` is immutable, so recreate the `RoleConflict` resource with a distinct `spec.role`, or point both resources at one `passwordSecretRef` in the same namespace.

## [0.5.1] - 2026-11-02

### Changed

- Collectors default to OTel Collector 0.164.0, from 0.161.0: the agent, scraper and PostgreSQL collectors on the contrib distribution, the gateway on the k8s distribution and the profiler on the eBPF profiler distribution. If you set `spec.image` or `profiling.image`, test the new release before moving to it.
- The PostgreSQL collector config uses the `sql_query` receiver name instead of its deprecated `sqlquery` alias (renamed upstream in 0.159.0). Emitted metrics and logs are unchanged.
