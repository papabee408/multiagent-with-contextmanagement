#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="${1:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: bash scripts/bootstrap-task.sh <task-id>" >&2
  exit 1
fi

mkdir -p "$TASKS_DIR"
ensure_runtime_dirs "$TASK_ID"

TASK_FILE="$(task_file "$TASK_ID")"
if [[ ! -f "$TASK_FILE" ]]; then
  sed "s/<task-id>/$TASK_ID/g" "$TASKS_DIR/_template.md" > "$TASK_FILE"
  touch_task_updated_at "$TASK_ID"
  echo "[OK] created task file: docs/tasks/$TASK_ID.md"
fi

if [[ ! -f "$(baseline_file "$TASK_ID")" ]]; then
  capture_baseline_snapshot "$TASK_ID"
  echo "[OK] captured baseline snapshot for task: $TASK_ID"
fi

mkdir -p "$CONTEXT_DIR"
printf '%s\n' "$TASK_ID" > "$ACTIVE_TASK_FILE"
echo "[OK] active task set: $TASK_ID"

bash "$ROOT_DIR/scripts/refresh-current.sh" "$TASK_ID" >/dev/null
echo "[OK] refreshed .context/current.md"
