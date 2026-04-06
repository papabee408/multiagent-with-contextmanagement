#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh" "${1:-}"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "[FAIL] scope: missing plan file ($PLAN_FILE)"
  exit 1
fi

changed=()
while IFS= read -r line; do
  [[ -n "$line" ]] && changed+=("$line")
done < <(changed_files)

allowed=()
while IFS= read -r line; do
  [[ -n "$line" ]] && allowed+=("$line")
done < <(allowed_files_from_plan)

if [[ ${#changed[@]} -eq 0 ]]; then
  echo "[PASS] scope (no changes)"
  exit 0
fi

if [[ ${#allowed[@]} -eq 0 ]]; then
  echo "[FAIL] scope: no target files defined in plan.md"
  exit 1
fi

allow_tmp="$(mktemp)"
trap 'rm -f "$allow_tmp"' EXIT
printf '%s\n' "${allowed[@]}" > "$allow_tmp"

violations=()
for f in "${changed[@]}"; do
  if grep -Fxq "$f" "$allow_tmp"; then
    continue
  fi
  if is_workflow_internal_file "$f"; then
    continue
  fi
  violations+=("$f")
done

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "[FAIL] scope: changed files outside plan target files"
  printf ' - %s\n' "${violations[@]}"
  exit 1
fi

echo "[PASS] scope"
