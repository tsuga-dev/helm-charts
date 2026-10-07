# tsuga-operator

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Helm chart for the Tsuga Operator, which manages Tsuga dashboards, monitors, SLOs and Kubernetes telemetry collection as code.

Operator documentation: <https://tsuga-dev.github.io/tsuga-operator/>

## Prerequisites

- A Tsuga **operation key** (Settings in the Tsuga app). The operator needs it to start, even for collection-only use.
- For telemetry collection only (`TsugaCollectorConfig`, `TsugaMonitoring`, `TsugaPostgresMonitoring`): cert-manager and the OpenTelemetry Operator v0.159.0, plus an OTLP ingestion key and endpoint. See the [operator getting-started guide](https://tsuga-dev.github.io/tsuga-operator/getting-started/). If you install them after this chart, restart the operator so it discovers their CRDs.

## Install

Install into `tsuga-operator-system`: `TsugaCollectorConfig.spec.collectorNamespace` defaults to it.

```bash
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
helm install tsuga-operator tsuga-charts/tsuga-operator \
  --namespace tsuga-operator-system --create-namespace \
  --set credentials.apiToken="<OPERATION_KEY>"
```

### Credentials

By default the chart creates the `tsuga-credentials` Secret the operator docs refer to:

| Value | Secret key | Used by |
| --- | --- | --- |
| `credentials.apiToken` (required) | `api-token` | Operator (Dashboard, Monitor, SLO API calls) |
| `credentials.apiKey` | `api-key` | Collectors, via `TsugaCollectorConfig.spec.export.tokenSecretRef` |
| `credentials.otlpEndpoint` | `otlp-endpoint` | Collectors, via `TsugaCollectorConfig.spec.export.endpointSecretRef` |

To manage the Secret yourself (External Secrets, sealed secrets, GitOps), set `credentials.create=false` and create a Secret named `credentials.secretName` with the same keys.

## CRDs

CRDs are rendered from `conf/crds/` when `crds.create=true` (the default), so `helm upgrade` updates them. They are annotated with `helm.sh/resource-policy: keep`: `helm uninstall` leaves the CRDs and your custom resources in place. Deleting a Dashboard, Monitor or SLO CR deletes the remote Tsuga object, so remove CRDs deliberately, with the operator still running:

```bash
kubectl delete crd dashboards.observability.tsuga.com monitors.observability.tsuga.com slos.observability.tsuga.com \
  tsugacollectorconfigs.observability.tsuga.com tsugamonitorings.observability.tsuga.com tsugapostgresmonitorings.observability.tsuga.com
```

To bump the CRDs to a new operator release, copy `config/crd/bases/*.yaml` from the matching `tsuga-operator` tag into `conf/crds/`.

## Metrics

The manager serves metrics on `:8443` over HTTPS with Kubernetes authn/authz. Scrapers must be bound to the `<fullname>-metrics-reader` ClusterRole. Set `manager.serviceMonitor.enabled=true` to create a Prometheus Operator ServiceMonitor.

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Tsuga | <hello@tsuga.com> |  |

## Source Code

* <https://github.com/tsuga-dev/helm-charts>
* <https://github.com/tsuga-dev/tsuga-operator>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| clusterRole.create | bool | `true` | Create the manager and metrics ClusterRoles and ClusterRoleBindings. |
| crds.annotations | object | `{}` | Extra annotations on every CRD. |
| crds.create | bool | `true` | Install the observability.tsuga.com CRDs. They carry `helm.sh/resource-policy: keep`, so uninstalling the chart leaves them (and your CRs) in place. |
| credentials.apiKey | string | `""` | Optional OTLP ingestion key for collectors, stored under `api-key`. Reference it from `TsugaCollectorConfig.spec.export.tokenSecretRef`. |
| credentials.apiToken | string | `""` | Tsuga operation key, stored under `api-token`. Required when `credentials.create` is true. Raw key, no `Bearer ` prefix. |
| credentials.create | bool | `true` | Create the credentials Secret from the values below. Set to false to reference a Secret you manage yourself (same name and keys). |
| credentials.otlpEndpoint | string | `""` | Optional OTLP endpoint for collectors, stored under `otlp-endpoint`. Reference it from `TsugaCollectorConfig.spec.export.endpointSecretRef`. |
| credentials.secretName | string | `"tsuga-credentials"` | Secret name. The operator docs and examples use `tsuga-credentials`. |
| fullnameOverride | string | `""` | Override full chart release name. |
| imagePullSecrets | list | `[]` | Image pull secrets for the manager pod. |
| manager.extraArgs | list | `[]` | Extra manager arguments. |
| manager.extraEnvs | list | `[]` | Extra environment variables. |
| manager.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| manager.image.repository | string | `"ghcr.io/tsuga-dev/tsuga-operator"` | Operator image repository. |
| manager.image.tag | string | `""` | Operator image tag. Defaults to the chart appVersion. |
| manager.leaderElection.enabled | bool | `true` | Run with `--leader-elect`. |
| manager.metrics.enabled | bool | `true` | Expose the metrics endpoint and its Service. |
| manager.metrics.secure | bool | `true` | Serve metrics over HTTPS with Kubernetes authn/authz (`--metrics-secure`). Scrapers need the `<fullname>-metrics-reader` ClusterRole. |
| manager.podAnnotations | object | `{}` | Pod annotations. |
| manager.podLabels | object | `{}` | Pod labels. |
| manager.ports.healthzPort | int | `8081` | Health probe port. |
| manager.ports.metricsPort | int | `8443` | Metrics port. |
| manager.resources.limits.cpu | string | `"500m"` |  |
| manager.resources.limits.memory | string | `"512Mi"` |  |
| manager.resources.requests.cpu | string | `"10m"` |  |
| manager.resources.requests.memory | string | `"64Mi"` |  |
| manager.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container security context. |
| manager.serviceAccount.annotations | object | `{}` | ServiceAccount annotations. |
| manager.serviceAccount.create | bool | `true` | Create the manager ServiceAccount. |
| manager.serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the full name. |
| manager.serviceMonitor.enabled | bool | `false` | Create a Prometheus Operator ServiceMonitor for the metrics Service. |
| manager.serviceMonitor.extraLabels | object | `{}` | Extra labels on the ServiceMonitor. |
| manager.tsugaBaseUrl | string | `"https://api.tsuga.com"` | Tsuga management API base URL. Must be https. |
| nameOverride | string | `""` | Override chart name. |
| nodeSelector."kubernetes.io/os" | string | `"linux"` |  |
| priorityClassName | string | `""` | Priority class for the manager pod. |
| replicaCount | int | `1` | Number of manager replicas. Only the leader reconciles when leader election is on. |
| role.create | bool | `true` | Create the leader-election Role and RoleBinding. |
| securityContext | object | `{"fsGroup":65532,"runAsGroup":65532,"runAsNonRoot":true,"runAsUser":65532,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context. |
| tolerations | list | `[]` |  |
| topologySpreadConstraints | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
