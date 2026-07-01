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
