#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
LOG_FILE="$(verification_log_file "$TASK_ID")"
RECEIPT_FILE="$(verification_receipt_file "$TASK_ID")"
TRACKED_RECEIPT_FILE="$(tracked_verification_receipt_file "$TASK_ID")"
TASK_FILE="$(task_file "$TASK_ID")"

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" in_progress review
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
for command in "${commands[@]}"; do
  {
    echo ""
    echo "\$ $command"
  } >> "$LOG_FILE"

  if ! bash -lc "cd \"$ROOT_DIR\" && $command" >> "$LOG_FILE" 2>&1; then
    result="FAIL"
    break
  fi
done

fingerprint="$(task_fingerprint "$TASK_ID")"

if [[ "$result" != "PASS" ]]; then
  {
    echo "result=$result"
    echo "executed_at_utc=$(utc_now)"
    echo "fingerprint=$fingerprint"
    echo "log_file=.context/tasks/$TASK_ID/verification.log"
  } > "$RECEIPT_FILE"
  sync_receipt_to_tracked "$RECEIPT_FILE" "$TRACKED_RECEIPT_FILE"

  touch_task_updated_at "$TASK_ID"
  replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "verification failed for the current diff"
  replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "inspect .context/tasks/$TASK_ID/verification.log and fix the failing command"

  bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

  echo "[FAIL] verification"
  echo " - task=$TASK_ID"
  echo " - log=.context/tasks/$TASK_ID/verification.log"
  exit 1
fi

{
  echo "result=$result"
  echo "executed_at_utc=$(utc_now)"
  echo "fingerprint=$fingerprint"
  echo "log_file=.context/tasks/$TASK_ID/verification.log"
} > "$RECEIPT_FILE"
sync_receipt_to_tracked "$RECEIPT_FILE" "$TRACKED_RECEIPT_FILE"

touch_task_updated_at "$TASK_ID"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "verification recorded for the current approved diff"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "run bash scripts/review-scope.sh $TASK_ID and bash scripts/review-quality.sh $TASK_ID"

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

echo "[PASS] verification"
echo " - task=$TASK_ID"
echo " - receipt=.context/tasks/$TASK_ID/verification.receipt"
