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
    ] | .[0:3]' 2>/dev/null || echo '[]')"
fi

count="$(printf '%s' "$matrix" | jq 'length' 2>/dev/null || echo 0)"
if [[ "$count" -lt 3 ]]; then
  echo "resolve-collector-versions: release lookup failed/incomplete; using FALLBACK_VERSIONS" >&2
  # shellcheck disable=SC2086
  matrix="$(printf '%s\n' ${FALLBACK_VERSIONS:-} | jq -R . | jq -s -c 'map(select(length > 0))')"
fi

final_count="$(printf '%s' "$matrix" | jq 'length' 2>/dev/null || echo 0)"
if [[ "$final_count" -lt 1 ]]; then
  echo "resolve-collector-versions: no versions resolved (matrix empty); failing" >&2
  exit 1
fi

echo "$matrix"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "matrix=$matrix" >> "$GITHUB_OUTPUT"
fi
