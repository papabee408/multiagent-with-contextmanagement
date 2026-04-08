#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/features/_template" \
  "$TMP_DIR/docs/features/feature-1" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/_run_log_helpers.sh" "$TMP_DIR/scripts/_run_log_helpers.sh"
cp "$ROOT_DIR/scripts/_role_receipt_helpers.sh" "$TMP_DIR/scripts/_role_receipt_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/dispatch-heartbeat.sh" "$TMP_DIR/scripts/dispatch-heartbeat.sh"
cp "$ROOT_DIR/scripts/dispatch-role.sh" "$TMP_DIR/scripts/dispatch-role.sh"
cp "$ROOT_DIR/scripts/record-role-result.sh" "$TMP_DIR/scripts/record-role-result.sh"
cp "$ROOT_DIR/scripts/finish-role.sh" "$TMP_DIR/scripts/finish-role.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
cp "$ROOT_DIR/scripts/gates/check-implementer-ready.sh" "$TMP_DIR/scripts/gates/check-implementer-ready.sh"
cp "$ROOT_DIR/docs/features/_template/run-log.md" "$TMP_DIR/docs/features/feature-1/run-log.md"

chmod +x \
  "$TMP_DIR/scripts/dispatch-heartbeat.sh" \
  "$TMP_DIR/scripts/dispatch-role.sh" \
  "$TMP_DIR/scripts/record-role-result.sh" \
  "$TMP_DIR/scripts/finish-role.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/scripts/gates/check-brief.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
feature_id="${1:-}"
if [[ -f "docs/features/$feature_id/brief.md" ]]; then
  echo "[PASS] brief"
  exit 0
fi
echo "[FAIL] brief"
echo " - missing-brief"
exit 1
EOF

cat > "$TMP_DIR/scripts/gates/check-plan.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
feature_id="${1:-}"
if [[ -f "docs/features/$feature_id/plan.md" ]]; then
  echo "[PASS] plan"
  exit 0
fi
echo "[FAIL] plan"
echo " - missing-plan"
exit 1
EOF

cat > "$TMP_DIR/scripts/gates/check-handoffs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
feature_id="${1:-}"
if [[ -f "docs/features/$feature_id/.ready-for-implementer" ]]; then
  echo "[PASS] handoffs"
  exit 0
fi
echo "[FAIL] handoffs"
echo " - implementer-handoff:stale-plan-sha"
exit 1
EOF

chmod +x \
  "$TMP_DIR/scripts/gates/check-brief.sh" \
  "$TMP_DIR/scripts/gates/check-plan.sh" \
  "$TMP_DIR/scripts/gates/check-handoffs.sh"

cat > "$TMP_DIR/docs/features/feature-1/brief.md" <<'EOF'
# Feature Brief
EOF

cat > "$TMP_DIR/docs/features/feature-1/plan.md" <<'EOF'
# Feature Plan
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

if bash scripts/dispatch-role.sh implementer "apply task cards" >/dev/null 2>&1; then
  echo "[FAIL] expected implementer dispatch to stay blocked before handoffs are ready"
  exit 1
fi

touch docs/features/feature-1/.ready-for-implementer
ready_output="$(bash scripts/gates/check-implementer-ready.sh --feature feature-1)"
printf '%s\n' "$ready_output" | grep -Fq '[PASS] implementer-ready'

finish_output="$(bash scripts/finish-role.sh planner "plan.md synced" --next-role implementer --next-action "apply task cards")"
printf '%s\n' "$finish_output" | grep -Fq 'current-role: implementer'
printf '%s\n' "$finish_output" | grep -Fq 'current-status: `QUEUED`'
printf '%s\n' "$finish_output" | grep -Eq '^started-at-utc:[[:space:]]*$'
printf '%s\n' "$finish_output" | grep -Eq '^interrupt-after-utc:[[:space:]]*$'
printf '%s\n' "$finish_output" | grep -Fq 'last-progress: apply task cards'

bash scripts/record-role-result.sh security \
  --agent-id sec-301 \
  --scope "docs/features/feature-1/run-log.md" \
  --rq-covered "[RQ-001]" \
  --rq-missing "[]" \
  --result BLOCKED \
  --evidence "waiting on reviewer handoff" \
  --next-action "orchestrator" \
  --touched-files "[]" >/dev/null

grep -Fq -- '- agent-id: sec-301' docs/features/feature-1/run-log.md
grep -Fq -- '- result: BLOCKED' docs/features/feature-1/run-log.md
grep -Fq '## State-Machine Notes' docs/features/feature-1/run-log.md
grep -Fq '"role": "security"' docs/features/feature-1/artifacts/roles/security.json

echo "[PASS] run-log-ops smoke"
