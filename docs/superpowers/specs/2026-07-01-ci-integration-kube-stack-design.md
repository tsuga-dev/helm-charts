# CI Integration Test: opentelemetry-kube-stack on kind

**Date:** 2026-07-01
**Status:** Approved (design), pending implementation
**Chart:** `charts/opentelemetry-kube-stack`

## Goal

Add a GitHub Actions workflow that deploys `opentelemetry-kube-stack` to an
ephemeral kind cluster using `values_ci_test.yaml` (Tsuga exporter disabled for
all components, debug exporters, no secret), and verifies:

1. All collector workloads start and stay Ready (no crashloops).
2. Collector logs contain no real errors (`error`/`fatal`-level, config-load
   failures, `status: unavailable`) — these **fail** the build.
3. Any `warn`-level log lines are surfaced non-blocking: as a sticky PR comment
   on `pull_request` runs, and in the job summary on `push` runs.

The deploy succeeding with no secret present also serves as the live
regression test for the secret-gating fix (`tsugaEnabled` helper): with the
Tsuga exporter disabled everywhere, no `otel-secret` is required.

## Non-goals

- No real Tsuga endpoint / OTLP export is exercised (debug exporters only).
- No assertion on telemetry *content* — only pod health and log cleanliness.
- Does not replace the existing static checks in `test.yml` (lint, unittest).

## File

New workflow: `.github/workflows/integration-kube-stack.yml`. Kept separate
from `test.yml` because this test is chart-specific (operator + CRDs + kind +
cert-manager) and slow (~4-6 min), so it should be isolated and independently
markable as a required check.

## Triggers & permissions

```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - "charts/opentelemetry-kube-stack/**"
      - ".github/workflows/integration-kube-stack.yml"
  push:
    branches: [main]
    paths:
      - "charts/opentelemetry-kube-stack/**"
      - ".github/workflows/integration-kube-stack.yml"

permissions:
  contents: read
  pull-requests: write   # for the warn comment
```

## Pinned versions (workflow `env`)

- `HELM_VERSION: "3.12.0"` (matches `test.yml`)
- `CERT_MANAGER_VERSION` — pinned cert-manager release (e.g. `v1.16.2`)
- `FALLBACK_VERSIONS` — space-separated collector versions used if the release
  API lookup fails (e.g. `0.155.0 0.154.0 0.153.0`)

All third-party actions pinned to a commit SHA (repo convention). Reuse the
`azure/setup-helm` SHA already in `test.yml`; pin `helm/kind-action`,
`peter-evans/find-comment`, `peter-evans/create-or-update-comment`, and
`actions/{upload,download}-artifact` to SHAs at implementation time.

## Job 1 — `resolve-versions`

Fast ubuntu job that computes the collector-version matrix.

- Query the GitHub API for the 3 most recent releases of
  `open-telemetry/opentelemetry-collector-releases`:
  `gh api repos/open-telemetry/opentelemetry-collector-releases/releases --paginate`
  (or `/releases?per_page=10`), filter tag names to `X.Y.Z` semver, drop
  pre-releases, take the top 3.
- Emit `matrix` as a JSON array output: `["0.155.0","0.154.0","0.153.0"]`.
- If the API call fails or yields fewer than 3 valid versions, use
  `FALLBACK_VERSIONS` and log a clear "falling back" message.
- All 3 will be recent (≥ v0.119), so they satisfy the chart's collector
  version guard.

Output: `matrix`.

## Job 2 — `integration`

`needs: resolve-versions`, `strategy: { fail-fast: false, matrix: { version:
${{ fromJson(needs.resolve-versions.outputs.matrix) }} } }`.

Step order:

1. `actions/checkout`.
2. `azure/setup-helm` (`HELM_VERSION`).
3. `helm/kind-action` — boot a single-node kind cluster.
4. **cert-manager:**
   `kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml`
   then `kubectl wait --for=condition=Available --timeout=3m deploy/cert-manager
   deploy/cert-manager-webhook deploy/cert-manager-cainjector -n cert-manager`.
5. `helm dependency build charts/opentelemetry-kube-stack` (pulls the
   opentelemetry-operator subchart and `otel-crds`).
6. **Install:**
   ```bash
   helm install otel charts/opentelemetry-kube-stack \
     -n otel --create-namespace \
     -f charts/opentelemetry-kube-stack/values_ci_test.yaml \
     --set agent.image=ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:${{ matrix.version }} \
     --set cluster.image=ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:${{ matrix.version }} \
     --set statefulset.image=ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s:${{ matrix.version }} \
     --wait --timeout 5m
   ```
   No secret is created; a successful install proves the secret-gating fix.
7. **Wait for workloads:** wait for the operator deployment Ready; then poll
   (with timeout ~2m) until operator-managed pods exist in `otel`
   (`-l app.kubernetes.io/managed-by=opentelemetry-operator`); then
   `kubectl wait --for=condition=Ready pod -l app.kubernetes.io/managed-by=opentelemetry-operator -n otel --timeout=4m`.
   Covers the agent DaemonSet, cluster-receiver Deployment, statefulset
   collector, and target-allocator. Use label selectors, not hardcoded names,
   to avoid coupling to the operator's naming scheme.
8. **Readiness gate:** short soak (~20s), then assert no container in the `otel`
   namespace has `restartCount > 0` and none are in `CrashLoopBackOff`.
9. **Error gate (fails the job):** collect logs from all managed collector pods
   and fail if any line matches a real-error pattern:
   - level column `error`, `fatal`, `dpanic`, or `panic`
     (collector console format: whitespace-delimited level after the
     timestamp — e.g. `<ts>\terror\t...`),
   - `status: unavailable` or `StatusRecoverableError` from the collector,
   - explicit config-load failures (`failed to get config`,
     `error decoding`, `invalid configuration`, `collector server run finished with error`).
   Grep is case-sensitive on the level token to avoid matching the word
   "error" inside benign messages; anchor on the level column where possible.
10. **Warn collection:** grep the same logs for the `warn` level column, write
    matches to `warns-${{ matrix.version }}.txt`, and upload as an artifact
    (always, even if empty). Also append them to `$GITHUB_STEP_SUMMARY`.
11. **On failure (`if: failure()`):** dump `kubectl get pods -A`,
    `kubectl describe` for otel pods, and recent logs to the step summary for
    debugging.

## Job 3 — `report-warns`

`needs: integration`, `if: always()`. Aggregates warns into a single, deduped
PR comment (matrix jobs can't share one comment cleanly, so aggregation is
done here).

- `actions/download-artifact` (all `warns-*` artifacts).
- Concatenate; if the combined result is non-empty **and** the event is
  `pull_request`:
  - `peter-evans/find-comment` to locate an existing comment carrying the
    hidden marker `<!-- integration-kube-stack-warns -->`,
  - `peter-evans/create-or-update-comment` to create-or-update a sticky comment
    (marker + a per-version summary of warn lines). Updating in place keeps one
    comment across re-runs.
- If the combined result is empty and a previous warn comment exists, update it
  to "No warnings detected ✅" (so a fixed PR doesn't keep showing stale warns).
- This job never fails the workflow — warns are informational.

## Testing / validation of the workflow itself

- Local dry run of the deploy path already verified:
  `helm template -f values_ci_test.yaml` renders with zero secret references
  and default values still inject them; 34 unit tests pass.
- The workflow will be validated by opening the PR and observing the run
  (matrix of 3 versions green, warn comment posted if any warns appear).
- The existing `legacy service.telemetry.resource` warning is already fixed, so
  a clean run is expected; if a future change reintroduces a config-schema
  error, the error gate will fail the matching version's job.

## Risks / open considerations

- **kind + operator timing:** the operator reconciles CRs into workloads
  asynchronously; the poll-until-pods-exist step (7) guards against racing
  `kubectl wait` before pods are created.
- **Runtime cost:** 3 parallel kind clusters, ~4-6 min each. Acceptable for a
  chart-scoped, path-filtered trigger.
- **Action SHAs:** must be pinned at implementation; unpinned tags violate repo
  convention and the workflow's own security posture.
- **Collector image repos:** agent/cluster use `-contrib`, statefulset uses
  `-k8s` (matches the chart template defaults). The version tag is shared.
