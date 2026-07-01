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
