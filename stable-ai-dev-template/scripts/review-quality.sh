#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
shift || true

SUMMARY=""
REUSE=""
HARDCODING=""
TESTS=""
REQUEST_SCOPE=""
RISK_CONTROLS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary)
      SUMMARY="${2:-}"
      shift 2
      ;;
    --reuse)
      REUSE="${2:-}"
      shift 2
      ;;
    --hardcoding)
      HARDCODING="${2:-}"
      shift 2
      ;;
    --tests)
      TESTS="${2:-}"
      shift 2
      ;;
    --request-scope)
      REQUEST_SCOPE="${2:-}"
      shift 2
      ;;
    --risk-controls)
      RISK_CONTROLS="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: bash scripts/review-quality.sh <task-id> --summary \"<review note>\" [--reuse pass|fail] [--hardcoding pass|fail] [--tests pass|fail] [--request-scope pass|fail] [--risk-controls pass|fail]" >&2
      exit 1
      ;;
  esac
done

TASK_FILE="$(task_file "$TASK_ID")"
RECEIPT_FILE="$(quality_review_receipt_file "$TASK_ID")"
RISK_LEVEL="$(task_risk_level "$TASK_ID")"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] review-quality"
  echo " - missing task file docs/tasks/$TASK_ID.md"
  exit 1
fi

if [[ -z "$SUMMARY" ]]; then
  echo "Usage: bash scripts/review-quality.sh <task-id> --summary \"<review note>\" [--reuse pass|fail] [--hardcoding pass|fail] [--tests pass|fail] [--request-scope pass|fail] [--risk-controls pass|fail]" >&2
  exit 1
fi

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" in_progress review
ensure_publish_late_base_branch_safe "$TASK_ID" "warn"
ensure_runtime_receipt_pass_and_fresh "$TASK_ID" "$(verification_receipt_file "$TASK_ID")" "verification"
bash "$ROOT_DIR/scripts/check-scope.sh" "$TASK_ID" >/dev/null

for value in "$REUSE" "$HARDCODING" "$TESTS" "$REQUEST_SCOPE" "$RISK_CONTROLS"; do
  if [[ -n "$value" ]]; then
    case "$(lower "$value")" in
      pass|fail)
        ;;
      *)
        echo "[FAIL] quality-review"
        echo " - review dimensions must be pass or fail"
        exit 1
        ;;
    esac
  fi
done

reuse_record="${REUSE:-n/a}"
hardcoding_record="${HARDCODING:-n/a}"
tests_record="${TESTS:-n/a}"
request_scope_record="${REQUEST_SCOPE:-n/a}"
risk_controls_record="${RISK_CONTROLS:-n/a}"

declare -a failures=()
case "$RISK_LEVEL" in
  trivial)
    ;;
  standard)
    [[ "$(lower "$REUSE")" == "pass" ]] || failures+=("reuse")
    [[ "$(lower "$HARDCODING")" == "pass" ]] || failures+=("hardcoding")
    [[ "$(lower "$TESTS")" == "pass" ]] || failures+=("tests")
    [[ "$(lower "$REQUEST_SCOPE")" == "pass" ]] || failures+=("request-scope")
    ;;
  high-risk)
    [[ "$(lower "$REUSE")" == "pass" ]] || failures+=("reuse")
    [[ "$(lower "$HARDCODING")" == "pass" ]] || failures+=("hardcoding")
    [[ "$(lower "$TESTS")" == "pass" ]] || failures+=("tests")
    [[ "$(lower "$REQUEST_SCOPE")" == "pass" ]] || failures+=("request-scope")
    [[ "$(lower "$RISK_CONTROLS")" == "pass" ]] || failures+=("risk-controls")
    ;;
esac

result="PASS"
if [[ ${#failures[@]} -gt 0 ]]; then
  result="FAIL"
fi

fingerprint="$(task_fingerprint "$TASK_ID")"
write_runtime_receipt "$RECEIPT_FILE" "$result" "$fingerprint" "$SUMMARY"
review_time="$(receipt_value "$RECEIPT_FILE" "executed_at_utc")"

replace_key_value_or_exit "$TASK_FILE" "## Review Status" "quality-review-status" "$(lower "$result")"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "quality-review-note" "$SUMMARY"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "quality-review-at-utc" "$review_time"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "quality-review-fingerprint" "$fingerprint"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "reuse-review" "$(lower "$reuse_record")"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "hardcoding-review" "$(lower "$hardcoding_record")"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "tests-review" "$(lower "$tests_record")"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "request-scope-review" "$(lower "$request_scope_record")"
replace_key_value_or_exit "$TASK_FILE" "## Review Status" "risk-controls-review" "$(lower "$risk_controls_record")"
replace_key_value_or_exit "$TASK_FILE" "## Status" "state" "review"
touch_task_updated_at "$TASK_ID"

if [[ "$result" != "PASS" ]]; then
  replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "quality review failed; address the recorded findings"
  replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "fix the review findings, rerun verification, then rerun quality review"

  bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

  echo "[FAIL] quality-review"
  printf ' - %s\n' "${failures[@]}"
  echo " - receipt=.context/tasks/$TASK_ID/quality-review.receipt"
  exit 1
fi

replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "quality review recorded; task is ready for completion when receipts stay fresh"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "run bash scripts/complete-task.sh $TASK_ID \"<summary>\" \"<next-step>\""

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

echo "[PASS] quality-review"
echo " - task=$TASK_ID"
echo " - receipt=.context/tasks/$TASK_ID/quality-review.receipt"
