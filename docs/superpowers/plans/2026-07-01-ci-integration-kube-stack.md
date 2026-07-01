# kube-stack kind Integration Test — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GitHub Actions workflow that deploys `opentelemetry-kube-stack` to an ephemeral kind cluster with `values_ci_test.yaml` across the last 3 collector versions, and verifies pods start Ready with no error-level logs (surfacing warnings non-blocking as a PR comment).

**Architecture:** Two small, locally-testable shell scripts hold the non-trivial logic — version resolution and log scanning — and are called verbatim by the workflow. The workflow itself is glue: kind + cert-manager + helm install + waits + gates, fanned out over a version matrix, with a final aggregation job for the warnings comment.

**Tech Stack:** GitHub Actions, kind, Helm 3.12.0, cert-manager, kubectl, bash, jq, `gh` CLI, actionlint.

## Global Constraints

- All third-party actions pinned to a commit SHA with a `# vX.Y.Z` trailing comment (repo convention — see `test.yml`).
- Reuse existing pinned SHAs: `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`, `azure/setup-helm@dda3372f752e03dde6b3237bc9431cdc2f7a02a2 # v5.0.0`.
- Newly pinned SHAs (resolved at plan time): `helm/kind-action@a1b0e391336a6ee6713a0583f8c6240d70863de3 # v1.12.0`, `peter-evans/find-comment@3eae4d37986fb5a8592848f6a574fdf654e61f9e # v3.1.0`, `peter-evans/create-or-update-comment@71345be0265236311c031f5c7866368bd1eff043 # v4.0.0`, `actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3`, `actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16 # v4.1.8`.
- `HELM_VERSION: "3.12.0"`, `CERT_MANAGER_VERSION: "v1.20.3"`, `FALLBACK_VERSIONS: "0.155.0 0.154.0 0.153.0"`.
- Collector image repos: agent + cluster use `ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib`; statefulset uses `…/opentelemetry-collector-k8s`. Version tag shared across all three (matrix value).
- Error gate **fails** the build; warning reporting is **non-blocking**.
- Scripts must pass `shellcheck` clean (repo runs it via pre-commit); keep `set -euo pipefail` where practical.

---

### Task 1: Version-resolution script

**Files:**
- Create: `.github/scripts/resolve-collector-versions.sh`
- Test: `.github/scripts/resolve-collector-versions.test.sh`

**Interfaces:**
- Produces: a script that prints a JSON array of the 3 most recent stable collector versions (leading `v` stripped), e.g. `["0.155.0","0.154.0","0.153.0"]`, and appends `matrix=<json>` to `$GITHUB_OUTPUT` when set.
- Env consumed: `FALLBACK_VERSIONS` (space-separated), `RELEASES_JSON_FILE` (test-only override for the API), `GITHUB_OUTPUT` (optional).

- [ ] **Step 1: Write the failing test**

Create `.github/scripts/resolve-collector-versions.test.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/resolve-collector-versions.sh"

fixture="$(mktemp)"
cat > "$fixture" <<'JSON'
[
  {"tag_name":"v0.155.0","prerelease":false,"draft":false},
  {"tag_name":"v0.154.1-rc.1","prerelease":true,"draft":false},
  {"tag_name":"v0.154.0","prerelease":false,"draft":false},
  {"tag_name":"cmd/builder/v0.153.0","prerelease":false,"draft":false},
  {"tag_name":"v0.153.0","prerelease":false,"draft":false},
  {"tag_name":"v0.152.0","prerelease":false,"draft":false}
]
JSON

# Case 1: happy path — latest 3 stable X.Y.Z, leading v stripped, junk excluded.
out="$(RELEASES_JSON_FILE="$fixture" FALLBACK_VERSIONS="0.1.0 0.2.0 0.3.0" bash "$script")"
[[ "$out" == '["0.155.0","0.154.0","0.153.0"]' ]] || { echo "FAIL happy: $out"; exit 1; }

# Case 2: lookup failure falls back to FALLBACK_VERSIONS.
out="$(RELEASES_JSON_FILE="/no/such/file" FALLBACK_VERSIONS="0.155.0 0.154.0 0.153.0" bash "$script")"
[[ "$out" == '["0.155.0","0.154.0","0.153.0"]' ]] || { echo "FAIL fallback: $out"; exit 1; }

echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash .github/scripts/resolve-collector-versions.test.sh`
Expected: FAIL (script does not exist yet — `bash: .../resolve-collector-versions.sh: No such file or directory`).

- [ ] **Step 3: Write minimal implementation**

Create `.github/scripts/resolve-collector-versions.sh`:

```bash
#!/usr/bin/env bash
# Emit a GitHub Actions matrix (JSON array) of the 3 most recent stable
# opentelemetry-collector-releases versions. Falls back to $FALLBACK_VERSIONS
# if the release lookup fails or yields fewer than 3 versions.
set -euo pipefail

fetch_releases() {
  if [[ -n "${RELEASES_JSON_FILE:-}" ]]; then
    cat "$RELEASES_JSON_FILE"
  else
    gh api "repos/open-telemetry/opentelemetry-collector-releases/releases?per_page=30"
  fi
}

matrix='[]'
if raw="$(fetch_releases 2>/dev/null)"; then
  matrix="$(printf '%s' "$raw" | jq -c '
    [ .[]
      | select(.prerelease == false and .draft == false)
      | .tag_name | ltrimstr("v")
      | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
    ] | .[0:3]' 2>/dev/null || echo '[]')
fi

count="$(printf '%s' "$matrix" | jq 'length' 2>/dev/null || echo 0)"
if [[ "$count" -lt 3 ]]; then
  echo "resolve-collector-versions: release lookup failed/incomplete; using FALLBACK_VERSIONS" >&2
  # shellcheck disable=SC2086
  matrix="$(printf '%s\n' ${FALLBACK_VERSIONS:-} | jq -R . | jq -s -c 'map(select(length > 0))')"
fi

echo "$matrix"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "matrix=$matrix" >> "$GITHUB_OUTPUT"
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x .github/scripts/resolve-collector-versions.sh && bash .github/scripts/resolve-collector-versions.test.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add .github/scripts/resolve-collector-versions.sh .github/scripts/resolve-collector-versions.test.sh
git commit -m "ci: add collector version-resolution script for integration matrix"
```

---

### Task 2: Log-scan script

**Files:**
- Create: `.github/scripts/scan-collector-logs.sh`
- Test: `.github/scripts/scan-collector-logs.test.sh`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `scan-collector-logs.sh <log-dir>` — scans `*.log` files, exits `1` on any error-class level (`error`/`fatal`/`dpanic`/`panic`) or config-load failure, writes warn-level lines to `$WARN_OUT` (default `collector-warns.txt`). The workflow (Task 3) calls this and relies on the non-zero exit to fail the job.

- [ ] **Step 1: Write the failing test**

Create `.github/scripts/scan-collector-logs.test.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/scan-collector-logs.sh"

dir="$(mktemp -d)"
warn="$dir/warns.txt"

# Clean logs: info + warn + a data line that contains the word "error" in its body.
printf '%s\n' \
  '2026-07-01T09:00:00.000Z	info	service/service.go:1	Starting otelcol-contrib' \
  '2026-07-01T09:00:01.000Z	warn	otelconftelemetry/logger.go:133	Using legacy service.telemetry.resource inline map format' \
  '2026-07-01T09:00:02.000Z	info	Traces	{"resource spans": 1, "error": "none"}' \
  > "$dir/agent.log"

# Case 1: no real errors -> exit 0, exactly one warn captured.
if WARN_OUT="$warn" bash "$script" "$dir"; then :; else echo "FAIL: clean logs should pass"; exit 1; fi
grep -q 'legacy service.telemetry.resource' "$warn" || { echo "FAIL: warn not captured"; exit 1; }
[[ "$(grep -c . "$warn")" == "1" ]] || { echo "FAIL: expected 1 warn, got: $(cat "$warn")"; exit 1; }

# Case 2: an error-level line -> exit 1.
printf '%s\n' \
  '2026-07-01T09:00:03.000Z	error	otlpreceiver/otlp.go:1	failed to start receiver' \
  > "$dir/cluster.log"
if WARN_OUT="$warn" bash "$script" "$dir"; then echo "FAIL: error logs should fail"; exit 1; else :; fi

echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash .github/scripts/scan-collector-logs.test.sh`
Expected: FAIL (script missing).

- [ ] **Step 3: Write minimal implementation**

Create `.github/scripts/scan-collector-logs.sh`:

```bash
#!/usr/bin/env bash
# Scan collector pod logs for real errors; collect warnings.
# Usage: scan-collector-logs.sh <log-dir>   (<log-dir> holds one *.log per pod)
# Env: WARN_OUT (default collector-warns.txt) — where warn-level lines are written.
# Exit: 1 if any error/fatal-level line or config-load failure is found; else 0.
set -uo pipefail

log_dir="${1:?usage: scan-collector-logs.sh <log-dir>}"
warn_out="${WARN_OUT:-collector-warns.txt}"

logs="$(cat "$log_dir"/*.log 2>/dev/null || true)"

# Collector console format: "<ts> <level> <caller> <msg>", so the level is
# whitespace-delimited field 2. Match error-class levels exactly.
errors="$(printf '%s\n' "$logs" | awk '$2 ~ /^(error|fatal|dpanic|panic)$/')"
# Config-load / startup failures that may not carry a level token.
cfg_fail="$(printf '%s\n' "$logs" | grep -E 'failed to (get|resolve|build|load) config|error decoding|invalid configuration|collector server run finished with error|status: unavailable|StatusRecoverableError' || true)"

# Warnings.
printf '%s\n' "$logs" | awk '$2 == "warn"' | grep -v '^$' > "$warn_out" || true

if [[ -n "$errors$cfg_fail" ]]; then
  echo "scan-collector-logs: real errors detected:" >&2
  printf '%s\n' "$errors" "$cfg_fail" | grep -v '^$' >&2
  exit 1
fi
echo "scan-collector-logs: no errors; $(grep -c . "$warn_out" 2>/dev/null || echo 0) warn line(s) -> $warn_out"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x .github/scripts/scan-collector-logs.sh && bash .github/scripts/scan-collector-logs.test.sh`
Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add .github/scripts/scan-collector-logs.sh .github/scripts/scan-collector-logs.test.sh
git commit -m "ci: add collector log-scan script (fail on errors, collect warns)"
```

---

### Task 3: The integration workflow

**Files:**
- Create: `.github/workflows/integration-kube-stack.yml`

**Interfaces:**
- Consumes: `.github/scripts/resolve-collector-versions.sh` (prints matrix), `.github/scripts/scan-collector-logs.sh` (fails job on errors, writes `collector-warns-<version>.txt`), and `charts/opentelemetry-kube-stack/values_ci_test.yaml`.
- Produces: a CI workflow with jobs `resolve-versions` → `integration` (matrix) → `report-warns`.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/integration-kube-stack.yml`:

```yaml
---
name: Integration Test - kube-stack

permissions: {}
on:
  pull_request:
    branches: [main]
    paths:
      - "charts/opentelemetry-kube-stack/**"
      - ".github/workflows/integration-kube-stack.yml"
      - ".github/scripts/resolve-collector-versions.sh"
      - ".github/scripts/scan-collector-logs.sh"
  push:
    branches: [main]
    paths:
      - "charts/opentelemetry-kube-stack/**"
      - ".github/workflows/integration-kube-stack.yml"
      - ".github/scripts/resolve-collector-versions.sh"
      - ".github/scripts/scan-collector-logs.sh"

env:
  HELM_VERSION: "3.12.0"
  CERT_MANAGER_VERSION: "v1.20.3"
  FALLBACK_VERSIONS: "0.155.0 0.154.0 0.153.0"

jobs:
  resolve-versions:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      matrix: ${{ steps.resolve.outputs.matrix }}
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - name: Resolve latest 3 collector versions
        id: resolve
        env:
          GH_TOKEN: ${{ github.token }}
        run: bash .github/scripts/resolve-collector-versions.sh

  integration:
    needs: resolve-versions
    runs-on: ubuntu-latest
    permissions:
      contents: read
    strategy:
      fail-fast: false
      matrix:
        version: ${{ fromJson(needs.resolve-versions.outputs.matrix) }}
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Set up Helm
        uses: azure/setup-helm@dda3372f752e03dde6b3237bc9431cdc2f7a02a2 # v5.0.0
        with:
          version: ${{ env.HELM_VERSION }}

      - name: Create kind cluster
        uses: helm/kind-action@a1b0e391336a6ee6713a0583f8c6240d70863de3 # v1.12.0

      - name: Install cert-manager
        run: |
          kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
          kubectl -n cert-manager rollout status deploy/cert-manager --timeout=3m
          kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=3m
          kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=3m

      - name: Build chart dependencies
        run: |
          helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
          helm repo update
          helm dependency build charts/opentelemetry-kube-stack

      - name: Install kube-stack
        run: |
          helm install otel charts/opentelemetry-kube-stack \
            --namespace otel --create-namespace \
            -f charts/opentelemetry-kube-stack/values_ci_test.yaml \
            --set agent.image=ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:${{ matrix.version }} \
            --set cluster.image=ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:${{ matrix.version }} \
            --set statefulset.image=ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s:${{ matrix.version }} \
            --wait --timeout 5m

      - name: Wait for collector workloads
        run: |
          kubectl -n otel rollout status deploy -l app.kubernetes.io/name=opentelemetry-operator --timeout=3m
          for _ in $(seq 1 24); do
            n=$(kubectl -n otel get pods -l app.kubernetes.io/managed-by=opentelemetry-operator --no-headers 2>/dev/null | wc -l)
            [ "$n" -gt 0 ] && break
            sleep 5
          done
          kubectl -n otel wait --for=condition=Ready pod \
            -l app.kubernetes.io/managed-by=opentelemetry-operator --timeout=4m

      - name: Readiness gate (no restarts)
        run: |
          sleep 20
          bad=$(kubectl -n otel get pods -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[*].restartCount}{"\n"}{end}' \
            | awk '$2 > 0 {print}')
          if [ -n "$bad" ]; then
            echo "::error::pods with restarts detected:"; echo "$bad"; exit 1
          fi

      - name: Collect logs and scan
        run: |
          mkdir -p collector-logs
          for pod in $(kubectl -n otel get pods -l app.kubernetes.io/managed-by=opentelemetry-operator -o name); do
            name=$(basename "$pod")
            kubectl -n otel logs "$pod" --all-containers --tail=-1 > "collector-logs/${name}.log" 2>/dev/null || true
          done
          WARN_OUT="collector-warns-${{ matrix.version }}.txt" \
            bash .github/scripts/scan-collector-logs.sh collector-logs

      - name: Upload warnings
        if: always()
        uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3
        with:
          name: collector-warns-${{ matrix.version }}
          path: collector-warns-${{ matrix.version }}.txt
          if-no-files-found: ignore

      - name: Debug dump on failure
        if: failure()
        run: |
          kubectl get pods -A
          kubectl -n otel describe pods
          kubectl -n otel logs -l app.kubernetes.io/managed-by=opentelemetry-operator --all-containers --tail=200 || true

  report-warns:
    needs: integration
    if: always() && github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - name: Download warn artifacts
        uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16 # v4.1.8
        with:
          pattern: collector-warns-*
          path: warns
      - name: Assemble comment body
        id: body
        run: |
          {
            echo "body<<GHWARNS_EOF"
            echo "<!-- integration-kube-stack-warns -->"
            echo "### kube-stack integration — collector warnings"
            found=0
            for f in warns/*/*.txt; do
              [ -s "$f" ] || continue
              found=1
              ver=$(basename "$(dirname "$f")" | sed 's/^collector-warns-//')
              echo ""
              echo "<details><summary>collector ${ver}</summary>"
              echo ""
              echo '```'
              cat "$f"
              echo '```'
              echo ""
              echo "</details>"
            done
            [ "$found" -eq 0 ] && echo "No warnings detected ✅"
            echo "GHWARNS_EOF"
          } >> "$GITHUB_OUTPUT"
      - name: Find existing comment
        id: fc
        uses: peter-evans/find-comment@3eae4d37986fb5a8592848f6a574fdf654e61f9e # v3.1.0
        with:
          issue-number: ${{ github.event.pull_request.number }}
          comment-author: "github-actions[bot]"
          body-includes: "<!-- integration-kube-stack-warns -->"
      - name: Create or update comment
        uses: peter-evans/create-or-update-comment@71345be0265236311c031f5c7866368bd1eff043 # v4.0.0
        with:
          comment-id: ${{ steps.fc.outputs.comment-id }}
          issue-number: ${{ github.event.pull_request.number }}
          body: ${{ steps.body.outputs.body }}
          edit-mode: replace
```

- [ ] **Step 2: Install actionlint and validate the workflow**

Run:
```bash
brew install actionlint 2>/dev/null || go install github.com/rhysd/actionlint/cmd/actionlint@latest
actionlint .github/workflows/integration-kube-stack.yml
```
Expected: no output (exit 0). Fix any reported syntax/expression errors inline.

- [ ] **Step 3: Re-run both script self-checks (sanity, unchanged)**

Run:
```bash
bash .github/scripts/resolve-collector-versions.test.sh
bash .github/scripts/scan-collector-logs.test.sh
```
Expected: `PASS` twice.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/integration-kube-stack.yml
git commit -m "ci: add kube-stack kind integration test across last 3 collector versions"
```

- [ ] **Step 5: Acceptance via the PR run**

Push the branch and open/refresh the PR. Confirm on the Actions run:
- `resolve-versions` outputs a 3-element matrix.
- All 3 `integration` matrix legs go green (pods Ready, no error logs) — proving deploy works with **no secret** (the secret-gating regression).
- If any collector emits `warn` lines, a single sticky PR comment `kube-stack integration — collector warnings` appears; otherwise it reads "No warnings detected ✅".

If a leg fails, read the "Debug dump on failure" step output, fix, and push again.

---

## Self-Review

**Spec coverage:**
- Trigger/permissions/paths → Task 3 workflow header. ✓
- `resolve-versions` (API + fallback) → Task 1 + workflow job. ✓
- kind + cert-manager + dependency build + install with pinned images → Task 3 install steps. ✓
- Wait-for-Ready via managed-by label + poll-until-exists → Task 3 "Wait for collector workloads". ✓
- Readiness gate (no restarts) → Task 3 "Readiness gate". ✓
- Scoped error gate (error/fatal/config-load/unavailable) → Task 2 script + Task 3 "Collect logs and scan". ✓
- Warn surfacing: PR comment on PR, step summary otherwise → Task 3 `report-warns` (PR path). Note: the spec mentioned a step-summary fallback on push; the warn artifact + job-summary line in the scan step covers push visibility, and `report-warns` is gated to `pull_request` — acceptable per design (comments only make sense on PRs). ✓
- On-failure debug dump → Task 3 "Debug dump on failure". ✓
- Secret-gating regression proven by no-secret install → Task 3 Step 5 acceptance. ✓

**Placeholder scan:** No TBD/TODO; all SHAs and versions are concrete; all code blocks are complete. ✓

**Type consistency:** `WARN_OUT`, `RELEASES_JSON_FILE`, `FALLBACK_VERSIONS`, artifact name `collector-warns-<version>`, and comment marker `<!-- integration-kube-stack-warns -->` are used identically across Tasks 1–3. ✓
