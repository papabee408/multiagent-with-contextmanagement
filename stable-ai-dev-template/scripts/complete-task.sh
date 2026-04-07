#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
SUMMARY="${2:-}"
NEXT_STEP="${3:-}"

if [[ -z "$SUMMARY" || -z "$NEXT_STEP" ]]; then
  echo "Usage: bash scripts/complete-task.sh <task-id> \"<summary>\" \"<next-step>\"" >&2
  exit 1
fi

TASK_FILE="$(task_file "$TASK_ID")"
TASK_BACKUP="$(mktemp)"
cp "$TASK_FILE" "$TASK_BACKUP"
RESTORE_TASK_FILE=1
cleanup() {
  if [[ "$RESTORE_TASK_FILE" == "1" && -f "$TASK_BACKUP" ]]; then
    cp "$TASK_BACKUP" "$TASK_FILE"
    bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null 2>&1 || true
  fi
  rm -f "$TASK_BACKUP"
}
trap cleanup EXIT

if placeholder_like "$SUMMARY"; then
  echo "[ERROR] completion summary must be specific, not a placeholder" >&2
  exit 1
fi
if placeholder_like "$NEXT_STEP"; then
  echo "[ERROR] completion next-step must be specific, not a placeholder" >&2
  exit 1
fi

bash "$ROOT_DIR/scripts/check-context.sh" >/dev/null
bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
bash "$ROOT_DIR/scripts/check-scope.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" review
ensure_publish_late_base_branch_safe "$TASK_ID" "warn"
ensure_runtime_receipt_pass_and_fresh "$TASK_ID" "$(verification_receipt_file "$TASK_ID")" "verification"
ensure_runtime_receipt_pass_and_fresh "$TASK_ID" "$(scope_review_receipt_file "$TASK_ID")" "scope-review"
ensure_runtime_receipt_pass_and_fresh "$TASK_ID" "$(quality_review_receipt_file "$TASK_ID")" "quality-review"

replace_key_value_or_exit "$TASK_FILE" "## Status" "state" "done"
touch_task_updated_at "$TASK_ID"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "task completed; ready to publish from the task branch"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "$NEXT_STEP"
replace_key_value_or_exit "$TASK_FILE" "## Completion" "summary" "$SUMMARY"
replace_key_value_or_exit "$TASK_FILE" "## Completion" "follow-up" "$NEXT_STEP"

if ! bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null; then
  echo "[FAIL] complete-task"
  echo " - task validation failed after applying completion fields; task file restored"
  exit 1
fi

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

RESTORE_TASK_FILE=0

if ! bash "$ROOT_DIR/scripts/record-task-metrics.sh" "$TASK_ID" >/dev/null; then
  echo "[WARN] template metrics were not recorded for task: $TASK_ID" >&2
fi

echo "[PASS] complete-task"
echo " - task=$TASK_ID"
