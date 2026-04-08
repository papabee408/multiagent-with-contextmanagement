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

epoch_to_utc() {
  perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M:%SZ", gmtime($ARGV[0]))' "$1"
}

queue_epoch=1700000000
start_epoch=1700000010
progress_epoch=1700000050
guard_risk_epoch=1700000105
guard_block_epoch=1700000171
done_epoch=1700000180
tester_start_epoch=1700000300

queue_output="$(DISPATCH_HEARTBEAT_NOW_EPOCH="$queue_epoch" bash scripts/dispatch-heartbeat.sh queue orchestrator "dispatching planner with brief.md" )"
printf '%s\n' "$queue_output" | grep -Fq "feature-id: feature-1"
printf '%s\n' "$queue_output" | grep -Fq 'current-role: orchestrator'
printf '%s\n' "$queue_output" | grep -Fq 'current-status: `QUEUED`'
printf '%s\n' "$queue_output" | grep -Eq '^started-at-utc:[[:space:]]*$'
printf '%s\n' "$queue_output" | grep -Eq '^interrupt-after-utc:[[:space:]]*$'

start_output="$(DISPATCH_HEARTBEAT_NOW_EPOCH="$start_epoch" bash scripts/dispatch-heartbeat.sh start planner "reading docs/features/feature-1/brief.md" )"
printf '%s\n' "$start_output" | grep -Fq 'current-role: planner'
printf '%s\n' "$start_output" | grep -Fq 'current-status: `RUNNING`'
printf '%s\n' "$start_output" | grep -Fq "started-at-utc: $(epoch_to_utc "$start_epoch")"
printf '%s\n' "$start_output" | grep -Fq "interrupt-after-utc: $(epoch_to_utc "$(( start_epoch + 120 ))")"
printf '%s\n' "$start_output" | grep -Fq 'last-progress: reading docs/features/feature-1/brief.md'

progress_output="$(DISPATCH_HEARTBEAT_NOW_EPOCH="$progress_epoch" bash scripts/dispatch-heartbeat.sh progress planner "updated docs/features/feature-1/plan.md" )"
printf '%s\n' "$progress_output" | grep -Fq 'current-status: `RUNNING`'
printf '%s\n' "$progress_output" | grep -Fq "interrupt-after-utc: $(epoch_to_utc "$(( progress_epoch + 120 ))")"
printf '%s\n' "$progress_output" | grep -Fq 'last-progress: updated docs/features/feature-1/plan.md'

guard_risk_output="$(DISPATCH_HEARTBEAT_NOW_EPOCH="$guard_risk_epoch" bash scripts/dispatch-heartbeat.sh guard)"
printf '%s\n' "$guard_risk_output" | grep -Fq 'current-status: `AT_RISK`'
printf '%s\n' "$guard_risk_output" | grep -Fq "last-progress-at-utc: $(epoch_to_utc "$progress_epoch")"
printf '%s\n' "$guard_risk_output" | grep -Fq "interrupt-after-utc: $(epoch_to_utc "$(( progress_epoch + 120 ))")"

guard_block_output="$(DISPATCH_HEARTBEAT_NOW_EPOCH="$guard_block_epoch" bash scripts/dispatch-heartbeat.sh guard)"
printf '%s\n' "$guard_block_output" | grep -Fq 'current-status: `BLOCKED`'
printf '%s\n' "$guard_block_output" | grep -Fq "last-progress-at-utc: $(epoch_to_utc "$progress_epoch")"

done_output="$(DISPATCH_HEARTBEAT_NOW_EPOCH="$done_epoch" bash scripts/dispatch-heartbeat.sh done planner "plan.md and test-matrix.md updated" )"
printf '%s\n' "$done_output" | grep -Fq 'current-status: `DONE`'
printf '%s\n' "$done_output" | grep -Fq "interrupt-after-utc: $(epoch_to_utc "$(( done_epoch + 120 ))")"
printf '%s\n' "$done_output" | grep -Fq 'last-progress: plan.md and test-matrix.md updated'

tester_start_output="$(DISPATCH_HEARTBEAT_NOW_EPOCH="$tester_start_epoch" bash scripts/dispatch-heartbeat.sh start tester "running tests for handoff" )"
printf '%s\n' "$tester_start_output" | grep -Fq 'current-role: tester'
printf '%s\n' "$tester_start_output" | grep -Fq 'current-status: `RUNNING`'
printf '%s\n' "$tester_start_output" | grep -Fq "started-at-utc: $(epoch_to_utc "$tester_start_epoch")"
printf '%s\n' "$tester_start_output" | grep -Fq "interrupt-after-utc: $(epoch_to_utc "$(( tester_start_epoch + 120 ))")"
printf '%s\n' "$tester_start_output" | grep -Fq 'last-progress: running tests for handoff'

show_output="$(bash scripts/dispatch-heartbeat.sh show)"
printf '%s\n' "$show_output" | grep -Fq 'feature-id: feature-1'
printf '%s\n' "$show_output" | grep -Fq 'current-role: tester'

if bash scripts/dispatch-heartbeat.sh start invalid-role "bad role" >/dev/null 2>&1; then
  echo "[FAIL] expected invalid role to be rejected"
  exit 1
fi

grep -Fq -- "- started-at-utc: $(epoch_to_utc "$tester_start_epoch")" \
  "$TMP_DIR/docs/features/feature-1/run-log.md"
grep -Fq -- "- interrupt-after-utc: $(epoch_to_utc "$(( tester_start_epoch + 120 ))")" \
  "$TMP_DIR/docs/features/feature-1/run-log.md"

echo "[PASS] dispatch-heartbeat smoke"
