#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
shift || true

APPROVED_BY=""
APPROVAL_NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --by)
      APPROVED_BY="${2:-}"
      shift 2
      ;;
    --note)
      APPROVAL_NOTE="${2:-}"
      shift 2
      ;;
    *)
      echo "Usage: bash scripts/approve-task.sh <task-id> --by \"<approver>\" --note \"<approval note>\"" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$APPROVED_BY" || -z "$APPROVAL_NOTE" ]]; then
  echo "Usage: bash scripts/approve-task.sh <task-id> --by \"<approver>\" --note \"<approval note>\"" >&2
  exit 1
fi

TASK_FILE="$(task_file "$TASK_ID")"
if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] approve-task"
  echo " - missing task file docs/tasks/$TASK_ID.md"
  exit 1
fi

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" awaiting_approval

replace_key_value_or_exit "$TASK_FILE" "## Status" "state" "approved"
replace_key_value_or_exit "$TASK_FILE" "## Approval" "approved-by" "$APPROVED_BY"
replace_key_value_or_exit "$TASK_FILE" "## Approval" "approved-at-utc" "$(utc_now)"
replace_key_value_or_exit "$TASK_FILE" "## Approval" "approval-note" "$APPROVAL_NOTE"
touch_task_updated_at "$TASK_ID"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "task approved; implementation has not started"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "run bash scripts/start-task.sh $TASK_ID before editing target files"

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

echo "[PASS] approve-task"
echo " - task=$TASK_ID"
