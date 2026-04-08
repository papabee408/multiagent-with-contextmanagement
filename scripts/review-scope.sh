#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
shift || true

SUMMARY="scope matches the approved target files"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary)
      SUMMARY="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: bash scripts/review-scope.sh <task-id> [--summary \"<review note>\"]" >&2
      exit 1
      ;;
  esac
done

TASK_FILE="$(task_file "$TASK_ID")"
RECEIPT_FILE="$(scope_review_receipt_file "$TASK_ID")"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] review-scope"
  echo " - missing task file docs/tasks/$TASK_ID.md"
  exit 1
fi

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" in_progress review
ensure_publish_late_base_branch_safe "$TASK_ID" "warn"
ensure_runtime_receipt_pass_and_fresh "$TASK_ID" "$(verification_receipt_file "$TASK_ID")" "verification"
bash "$ROOT_DIR/scripts/check-scope.sh" "$TASK_ID" >/dev/null

fingerprint="$(task_fingerprint "$TASK_ID")"
write_runtime_receipt "$RECEIPT_FILE" "PASS" "$fingerprint" "$SUMMARY"
review_time="$(receipt_value "$RECEIPT_FILE" "executed_at_utc")"

replace_key_value_or_exit "$TASK_FILE" "## Review Status" "scope-review-status" "pass"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "scope-review-note" "$SUMMARY"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "scope-review-at-utc" "$review_time"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "scope-review-fingerprint" "$fingerprint"
replace_key_value_or_exit "$TASK_FILE" "## Status" "state" "review"
touch_task_updated_at "$TASK_ID"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "scope review recorded; finish the remaining review work"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "run bash scripts/review-quality.sh $TASK_ID --summary \"<quality note>\" ..."

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

echo "[PASS] scope-review"
echo " - task=$TASK_ID"
echo " - receipt=.context/tasks/$TASK_ID/scope-review.receipt"
