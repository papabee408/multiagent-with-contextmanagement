#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
TASK_FILE="$(task_file "$TASK_ID")"
CHECK_SCOPE_MODE="${CHECK_SCOPE_MODE:-local}"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] scope: missing task file docs/tasks/$TASK_ID.md"
  exit 1
fi

case "$CHECK_SCOPE_MODE" in
  ""|local)
    CHANGED_FILE_SOURCE="effective"
    ;;
  ci)
    CHANGED_FILE_SOURCE="committed"
    ;;
  *)
    echo "[FAIL] scope: unsupported CHECK_SCOPE_MODE '$CHECK_SCOPE_MODE'" >&2
    exit 1
    ;;
esac

scope_changed_files() {
  case "$CHANGED_FILE_SOURCE" in
    effective)
      effective_changed_files "$TASK_ID"
      ;;
    committed)
      task_committed_changed_files "$TASK_ID"
      ;;
  esac
}

allowed_tmp="$(mktemp)"
trap 'rm -f "$allowed_tmp"' EXIT

{
  target_files_from_task "$TASK_ID"
  printf '%s\n' "docs/tasks/$TASK_ID.md"
  printf '%s\n' "docs/context/DECISIONS.md"
  printf '%s\n' ".context/active_task"
} | sort -u > "$allowed_tmp"

violations=()
changed_count=0
while IFS= read -r relative_path; do
  [[ -n "$relative_path" ]] || continue
  changed_count=$((changed_count + 1))
  if is_workflow_internal_file "$TASK_ID" "$relative_path"; then
    continue
  fi
  if grep -Fxq "$relative_path" "$allowed_tmp"; then
    continue
  fi
  if path_allowed_by_task "$TASK_ID" "$relative_path"; then
    continue
  fi
  violations+=("$relative_path")
done < <(scope_changed_files)

if [[ "$changed_count" == "0" ]]; then
  echo "[PASS] scope (no task-owned changes)"
  exit 0
fi

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "[FAIL] scope"
  printf ' - %s\n' "${violations[@]}"
  exit 1
fi

echo "[PASS] scope"
