#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/docs/features/_template" \
  "$TMP_DIR/docs/features/feature-1" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/_run_log_helpers.sh" "$TMP_DIR/scripts/_run_log_helpers.sh"
cp "$ROOT_DIR/scripts/_role_receipt_helpers.sh" "$TMP_DIR/scripts/_role_receipt_helpers.sh"
cp "$ROOT_DIR/scripts/dispatch-heartbeat.sh" "$TMP_DIR/scripts/dispatch-heartbeat.sh"
cp "$ROOT_DIR/scripts/dispatch-role.sh" "$TMP_DIR/scripts/dispatch-role.sh"
cp "$ROOT_DIR/scripts/record-role-result.sh" "$TMP_DIR/scripts/record-role-result.sh"
cp "$ROOT_DIR/scripts/finish-role.sh" "$TMP_DIR/scripts/finish-role.sh"
cp "$ROOT_DIR/docs/features/_template/run-log.md" "$TMP_DIR/docs/features/feature-1/run-log.md"

chmod +x \
  "$TMP_DIR/scripts/dispatch-heartbeat.sh" \
  "$TMP_DIR/scripts/dispatch-role.sh" \
  "$TMP_DIR/scripts/record-role-result.sh" \
  "$TMP_DIR/scripts/finish-role.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

perl -0pi -e 's/- feature-id:/- feature-id: feature-1/' "$TMP_DIR/docs/features/feature-1/run-log.md"

cd "$TMP_DIR"

queue_output="$(bash scripts/dispatch-role.sh planner "prepare docs/features/feature-1/plan.md")"
printf '%s\n' "$queue_output" | grep -Fq 'current-role: planner'
printf '%s\n' "$queue_output" | grep -Fq 'current-status: `QUEUED`'

bash scripts/record-role-result.sh planner \
  --agent-id plan-201 \
  --scope "docs/features/feature-1/plan.md, docs/features/feature-1/implementer-handoff.md" \
  --rq-covered "[RQ-001]" \
  --rq-missing "[]" \
  --result PASS \
  --evidence "updated plan.md and synced handoffs" \
  --next-action "implementer" \
  --touched-files "docs/features/feature-1/plan.md, docs/features/feature-1/implementer-handoff.md" >/dev/null

grep -Fq -- '- agent-id: plan-201' docs/features/feature-1/run-log.md
grep -Fq -- '- evidence: updated plan.md and synced handoffs' docs/features/feature-1/run-log.md
grep -Fq '"role": "planner"' docs/features/feature-1/artifacts/roles/planner.json
grep -Fq '"agent_id": "plan-201"' docs/features/feature-1/artifacts/roles/planner.json
grep -Fq '"touched_files": [' docs/features/feature-1/artifacts/roles/planner.json

finish_output="$(bash scripts/finish-role.sh planner "plan.md synced" --next-role implementer --next-action "apply task cards")"
printf '%s\n' "$finish_output" | grep -Fq 'current-role: implementer'
printf '%s\n' "$finish_output" | grep -Fq 'current-status: `QUEUED`'
printf '%s\n' "$finish_output" | grep -Fq 'last-progress: apply task cards'

echo "[PASS] run-log-ops smoke"
