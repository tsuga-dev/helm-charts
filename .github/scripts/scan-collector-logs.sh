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
cfg_fail="$(printf '%s\n' "$logs" | grep -E '^Error:|collector server run finished with error|error decoding|invalid configuration' || true)"

# Warnings.
printf '%s\n' "$logs" | awk '$2 == "warn"' | grep -v '^$' > "$warn_out" || true

if [[ -n "$errors$cfg_fail" ]]; then
  echo "scan-collector-logs: real errors detected:" >&2
  printf '%s\n' "$errors" "$cfg_fail" | grep -v '^$' >&2
  exit 1
fi
echo "scan-collector-logs: no errors; $(awk 'END{print NR}' "$warn_out" 2>/dev/null || echo 0) warn line(s) -> $warn_out"
