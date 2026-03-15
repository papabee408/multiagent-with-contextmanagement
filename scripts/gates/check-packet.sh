#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FEATURE_ID="${1:-}"
FEATURE_DIR="$ROOT_DIR/docs/features/$FEATURE_ID"

required=(
  brief.md
  plan.md
  implementer-handoff.md
  tester-handoff.md
  reviewer-handoff.md
  security-handoff.md
  test-matrix.md
  run-log.md
)

if [[ -z "$FEATURE_ID" ]]; then
  echo "[FAIL] packet: feature-id is required"
  exit 1
fi

if [[ ! -d "$FEATURE_DIR" ]]; then
  echo "[FAIL] packet: missing directory docs/features/$FEATURE_ID"
  exit 1
fi

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
