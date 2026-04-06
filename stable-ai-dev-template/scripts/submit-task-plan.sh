#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
TASK_FILE="$(task_file "$TASK_ID")"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] submit-task-plan"
  echo " - missing task file docs/tasks/$TASK_ID.md"
  exit 1
fi

bash "$ROOT_DIR/scripts/check-context.sh" >/dev/null
bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" planning blocked

replace_key_value_or_exit "$TASK_FILE" "## Status" "state" "awaiting_approval"
touch_task_updated_at "$TASK_ID"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "waiting for user approval on the task plan"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "wait for approval or revise docs/tasks/$TASK_ID.md"

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

echo "[PASS] submit-task-plan"
echo " - task=$TASK_ID"

