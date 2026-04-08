#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FEATURE_ID="${1:-}"
FEATURE_DIR="$ROOT_DIR/docs/features/$FEATURE_ID"

if [[ -z "$FEATURE_ID" ]]; then
  echo "[FAIL] packet: feature-id is required"
  exit 1
fi

if [[ ! -d "$FEATURE_DIR" ]]; then
  echo "[FAIL] packet: missing directory docs/features/$FEATURE_ID"
  exit 1
fi

source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"

required=(
  brief.md
  plan.md
  test-matrix.md
  run-log.md
)

while IFS= read -r handoff_file; do
  [[ -n "$handoff_file" ]] || continue
  required+=("$handoff_file")
done < <(required_handoff_files_for_mode "$(workflow_mode_from_brief)")

missing=()
for file in "${required[@]}"; do
  if [[ ! -f "$FEATURE_DIR/$file" ]]; then
    missing+=("$file")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "[FAIL] packet: missing files -> ${missing[*]}"
  exit 1
fi

echo "[PASS] packet"
