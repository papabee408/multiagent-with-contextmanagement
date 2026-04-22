#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/bootstrap-task.sh <task-id> [--supersedes <old-task-id> --reason "<why>"]
EOF
}

TASK_ID=""
SUPERSEDES_TASK_ID=""
SUPERSESSION_REASON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --supersedes)
      SUPERSEDES_TASK_ID="$(trim "${2:-}")"
      shift 2
      ;;
    --reason)
      SUPERSESSION_REASON="$(trim "${2:-}")"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$TASK_ID" ]]; then
        usage >&2
        exit 1
      fi
      TASK_ID="$1"
      shift
      ;;
  esac
done

if [[ -z "$TASK_ID" ]]; then
  usage >&2
  exit 1
fi

if [[ -n "$SUPERSEDES_TASK_ID" ]] && placeholder_like "$SUPERSESSION_REASON"; then
  echo "[ERROR] --reason is required when --supersedes is used" >&2
  exit 1
fi

mkdir -p "$TASKS_DIR"
ensure_runtime_dirs "$TASK_ID"

TASK_FILE="$(task_file "$TASK_ID")"
if [[ ! -f "$TASK_FILE" && -z "$SUPERSEDES_TASK_ID" ]] &&
  git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
  git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1 &&
  ! ensure_clean_worktree; then
  echo "[FAIL] bootstrap-task"
  echo " - start a new task from a clean worktree"
  exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
  sed "s/<task-id>/$TASK_ID/g" "$TASKS_DIR/_template.md" > "$TASK_FILE"
  touch_task_updated_at "$TASK_ID"
  echo "[OK] created task file: docs/tasks/$TASK_ID.md"
fi

if [[ ! -f "$(bootstrap_head_file "$TASK_ID")" ]]; then
  capture_bootstrap_head "$TASK_ID"
  echo "[OK] captured bootstrap head for task: $TASK_ID"
fi

if [[ -n "$SUPERSEDES_TASK_ID" ]]; then
  if [[ "$SUPERSEDES_TASK_ID" == "$TASK_ID" ]]; then
    echo "[ERROR] a task cannot supersede itself: $TASK_ID" >&2
    exit 1
  fi
  if ! task_exists "$SUPERSEDES_TASK_ID"; then
    echo "[ERROR] missing superseded task file: docs/tasks/$SUPERSEDES_TASK_ID.md" >&2
    exit 1
  fi

  ensure_task_state_in "$SUPERSEDES_TASK_ID" planning awaiting_approval approved in_progress review

  case "$(task_state "$TASK_ID")" in
    planning|awaiting_approval|approved|in_progress|review)
      ;;
    *)
      echo "[ERROR] replacement task must not already be terminal: $TASK_ID" >&2
      exit 1
      ;;
  esac

  mark_task_superseded "$SUPERSEDES_TASK_ID" "$TASK_ID" "$SUPERSESSION_REASON"
  echo "[OK] task superseded: $SUPERSEDES_TASK_ID -> $TASK_ID"
fi
