#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/docs/features/feature-1" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/dispatch-heartbeat.sh" "$TMP_DIR/scripts/dispatch-heartbeat.sh"
chmod +x "$TMP_DIR/scripts/dispatch-heartbeat.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/docs/features/feature-1/run-log.md" <<'EOF'
# Run Log

## Status
- feature-id: feature-1
- overall: `IN_PROGRESS`

## Dispatch Monitor
- current-role:
- current-status: `QUEUED | RUNNING | AT_RISK | BLOCKED | DONE`
- started-at-utc:
- last-progress-at-utc:
- interrupt-after-utc:
- last-progress:

## Evidence Rule
- `evidence` must name concrete files, commands, diffs, or raw outputs.
EOF

cd "$TMP_DIR"

queue_output="$(bash scripts/dispatch-heartbeat.sh queue orchestrator "dispatching planner with brief.md" )"
printf '%s\n' "$queue_output" | grep -Fq "feature-id: feature-1"
printf '%s\n' "$queue_output" | grep -Fq 'current-role: orchestrator'
printf '%s\n' "$queue_output" | grep -Fq 'current-status: `QUEUED`'
printf '%s\n' "$queue_output" | grep -Eq '^started-at-utc:[[:space:]]*$'
printf '%s\n' "$queue_output" | grep -Eq '^interrupt-after-utc:[[:space:]]*$'

start_output="$(bash scripts/dispatch-heartbeat.sh start planner "reading docs/features/feature-1/brief.md" )"
printf '%s\n' "$start_output" | grep -Fq 'current-role: planner'
printf '%s\n' "$start_output" | grep -Fq 'current-status: `RUNNING`'
printf '%s\n' "$start_output" | grep -Fq 'last-progress: reading docs/features/feature-1/brief.md'

risk_output="$(bash scripts/dispatch-heartbeat.sh risk planner "waiting on missing target files in plan.md" )"
printf '%s\n' "$risk_output" | grep -Fq 'current-status: `AT_RISK`'
printf '%s\n' "$risk_output" | grep -Fq 'last-progress: waiting on missing target files in plan.md'

done_output="$(bash scripts/dispatch-heartbeat.sh done planner "plan.md and test-matrix.md updated" )"
printf '%s\n' "$done_output" | grep -Fq 'current-status: `DONE`'
printf '%s\n' "$done_output" | grep -Fq 'last-progress: plan.md and test-matrix.md updated'

show_output="$(bash scripts/dispatch-heartbeat.sh show)"
printf '%s\n' "$show_output" | grep -Fq 'feature-id: feature-1'
printf '%s\n' "$show_output" | grep -Fq 'current-role: planner'

if bash scripts/dispatch-heartbeat.sh start invalid-role "bad role" >/dev/null 2>&1; then
  echo "[FAIL] expected invalid role to be rejected"
  exit 1
fi

grep -Eq '^- started-at-utc: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
  "$TMP_DIR/docs/features/feature-1/run-log.md"
grep -Eq '^- interrupt-after-utc: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
  "$TMP_DIR/docs/features/feature-1/run-log.md"

echo "[PASS] dispatch-heartbeat smoke"
