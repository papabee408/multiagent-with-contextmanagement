#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
LOG_FILE="$(verification_log_file "$TASK_ID")"
RECEIPT_FILE="$(verification_receipt_file "$TASK_ID")"
TASK_FILE="$(task_file "$TASK_ID")"

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" in_progress review
ensure_publish_late_base_branch_safe "$TASK_ID" "warn"
bash "$ROOT_DIR/scripts/check-scope.sh" "$TASK_ID" >/dev/null

ensure_runtime_dirs "$TASK_ID"

commands=()
while IFS= read -r command; do
  [[ -n "$command" ]] || continue
  commands+=("$command")
done < <(verification_commands_from_task "$TASK_ID")

if [[ ${#commands[@]} -eq 0 ]]; then
  echo "[ERROR] no verification commands found for task: $TASK_ID" >&2
  exit 1
fi

{
  echo "# Verification Log"
  echo "task=$TASK_ID"
  echo "started_at_utc=$(utc_now)"
} > "$LOG_FILE"

result="PASS"
failed_command=""
for command in "${commands[@]}"; do
  {
    echo ""
    echo "\$ $command"
  } >> "$LOG_FILE"

  if ! bash -lc "cd \"$ROOT_DIR\" && $command" >> "$LOG_FILE" 2>&1; then
    result="FAIL"
    failed_command="$command"
    break
  fi
done

fingerprint="$(task_fingerprint "$TASK_ID")"
summary="verification passed; see .context/tasks/$TASK_ID/verification.log"
if [[ "$result" != "PASS" ]]; then
  summary="verification failed at '$failed_command'; see .context/tasks/$TASK_ID/verification.log"
fi

write_runtime_receipt "$RECEIPT_FILE" "$result" "$fingerprint" "$summary"
verification_time="$(receipt_value "$RECEIPT_FILE" "executed_at_utc")"

replace_key_value_or_exit "$TASK_FILE" "## Verification Status" "verification-status" "$(lower "$result")"
replace_key_value_or_exit "$TASK_FILE" "## Verification Status" "verification-note" "$summary"
replace_key_value_or_exit "$TASK_FILE" "## Verification Status" "verification-at-utc" "$verification_time"
upsert_key_value_or_exit "$TASK_FILE" "## Verification Status" "verification-fingerprint" "$fingerprint"
touch_task_updated_at "$TASK_ID"

if [[ "$result" != "PASS" ]]; then
  echo "[FAIL] verification"
  echo " - task=$TASK_ID"
  echo " - log=.context/tasks/$TASK_ID/verification.log"
  exit 1
fi

echo "[PASS] verification"
echo " - task=$TASK_ID"
echo " - receipt=.context/tasks/$TASK_ID/verification.receipt"
