#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
TASK_FILE="$(task_file "$TASK_ID")"

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

echo "[PASS] start-task"
echo " - task=$TASK_ID"
