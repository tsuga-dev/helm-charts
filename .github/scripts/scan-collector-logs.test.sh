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

# Case 3: a bare startup "Error:" config-load failure -> exit 1.
dir3="$(mktemp -d)"
printf '%s\n' 'Error: failed to get config: cannot unmarshal the configuration: invalid exporter' > "$dir3/boot.log"
if WARN_OUT="$dir3/w.txt" bash "$script" "$dir3"; then echo "FAIL: config-load failure should fail"; exit 1; else :; fi

# Case 4: a benign info line containing "failed to get config" must NOT fail (regex is no longer level-agnostic).
dir4="$(mktemp -d)"
printf '%s\n' '2026-07-01T09:00:04.000Z	info	cache/cache.go:1	failed to get config from cache, will retry' > "$dir4/agent.log"
if WARN_OUT="$dir4/w.txt" bash "$script" "$dir4"; then :; else echo "FAIL: benign info line should not fail"; exit 1; fi

# Case 5: clean run with zero warnings prints a well-formed summary (no doubled count).
dir5="$(mktemp -d)"
printf '%s\n' '2026-07-01T09:00:05.000Z	info	service/service.go:1	Everything is fine' > "$dir5/agent.log"
out5="$(WARN_OUT="$dir5/w.txt" bash "$script" "$dir5")"
[[ "$out5" == "scan-collector-logs: no errors; 0 warn line(s) -> $dir5/w.txt" ]] || { echo "FAIL: malformed summary: $out5"; exit 1; }

echo "PASS"
