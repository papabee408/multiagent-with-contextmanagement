#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
TASK_FILE="$(task_file "$TASK_ID")"
BRANCH_STRATEGY="$(branch_strategy_from_task "$TASK_ID")"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] start-task"
  echo " - missing task file docs/tasks/$TASK_ID.md"
  exit 1
fi

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" approved
ensure_publish_late_base_branch_safe "$TASK_ID" "warn"

replace_key_value_or_exit "$TASK_FILE" "## Status" "state" "in_progress"
touch_task_updated_at "$TASK_ID"
replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "current focus" "implement the approved plan inside the target files only"

if [[ "$BRANCH_STRATEGY" == "publish-late" ]]; then
  replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "edit the approved files; before the first commit create or switch to $(task_branch_name "$TASK_ID"), then run verification"
else
  replace_key_value_or_exit "$TASK_FILE" "## Session Resume" "next action" "create or switch to $(task_branch_name "$TASK_ID") if needed, then edit approved files and run verification"
fi

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null

echo "[PASS] start-task"
echo " - task=$TASK_ID"
