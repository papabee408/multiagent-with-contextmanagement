#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
shift || true

REVIEWER=""
SUMMARY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reviewer)
      REVIEWER="${2:-}"
      shift 2
      ;;
    --summary)
      SUMMARY="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: bash scripts/review-independent.sh <task-id> --reviewer \"<agent-id>\" --summary \"<review note>\"" >&2
      exit 1
      ;;
  esac
done

TASK_FILE="$(task_file "$TASK_ID")"
RECEIPT_FILE="$(independent_review_receipt_file "$TASK_ID")"
TRACKED_RECEIPT_FILE="$(tracked_independent_review_receipt_file "$TASK_ID")"
RISK_LEVEL="$(task_risk_level "$TASK_ID")"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] independent-review"
  echo " - missing task file docs/tasks/$TASK_ID.md"
  exit 1
fi

if [[ -z "$REVIEWER" || -z "$SUMMARY" ]]; then
  echo "Usage: bash scripts/review-independent.sh <task-id> --reviewer \"<agent-id>\" --summary \"<review note>\"" >&2
  exit 1
fi

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" in_progress review
ensure_receipt_pass_and_fresh "$TASK_ID" "$(verification_receipt_file "$TASK_ID")" "verification"
bash "$ROOT_DIR/scripts/check-scope.sh" "$TASK_ID" >/dev/null

case "$RISK_LEVEL" in
  trivial)
    echo "[PASS] independent-review"
    echo " - task=$TASK_ID"
    echo " - skipped for trivial risk"
    exit 0
    ;;
  standard|high-risk)
    ensure_receipt_pass_and_fresh "$TASK_ID" "$(scope_review_receipt_file "$TASK_ID")" "scope-review"
    ensure_receipt_pass_and_fresh "$TASK_ID" "$(quality_review_receipt_file "$TASK_ID")" "quality-review"
    ;;
  *)
    echo "[FAIL] independent-review"
    echo " - unsupported risk level: $RISK_LEVEL"
    exit 1
    ;;
esac

{
  echo "result=PASS"
  echo "executed_at_utc=$(utc_now)"
  echo "fingerprint=$(task_fingerprint "$TASK_ID")"
  echo "reviewer=$REVIEWER"
  echo "summary=$SUMMARY"
} > "$RECEIPT_FILE"
sync_receipt_to_tracked "$RECEIPT_FILE" "$TRACKED_RECEIPT_FILE"

replace_key_value_or_exit "$TASK_FILE" "## Review Status" "independent-review-status" "pass"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "independent-review-note" "$SUMMARY"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "independent-reviewer" "$REVIEWER"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "independent-review-fingerprint" "$(task_fingerprint "$TASK_ID")"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "independent-review-proof" "$(independent_review_proof "$TASK_ID" "$REVIEWER" "$SUMMARY")"
replace_key_value_or_exit "$TASK_FILE" "## Status" "state" "review"
touch_task_updated_at "$TASK_ID"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "independent review recorded; task is ready for completion when all receipts stay fresh"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "run bash scripts/complete-task.sh $TASK_ID \"<summary>\" \"<next-step>\""

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

echo "[PASS] independent-review"
echo " - task=$TASK_ID"
echo " - reviewer=$REVIEWER"
echo " - receipt=.context/tasks/$TASK_ID/independent-review.receipt"
