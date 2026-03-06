#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURE_ID="${1:-}"
SETUP_STAMP_FILE="$ROOT_DIR/.context/setup-check.done"

if [[ -z "$FEATURE_ID" ]]; then
  echo "Usage: scripts/start-feature.sh <feature-id>"
  exit 1
fi

mkdir -p "$ROOT_DIR/.context"

if [[ ! -f "$SETUP_STAMP_FILE" ]]; then
  if "$ROOT_DIR/scripts/check-project-setup.sh"; then
    date -u +"%Y-%m-%d %H:%M:%SZ" > "$SETUP_STAMP_FILE"
  else
    echo "[ALERT] project setup check reported issues. Fix alerts to stop this reminder."
  fi
fi

if [[ -d "$ROOT_DIR/docs/features/$FEATURE_ID" ]]; then
  "$ROOT_DIR/scripts/set-active-feature.sh" "$FEATURE_ID"
else
  "$ROOT_DIR/scripts/feature-packet.sh" "$FEATURE_ID"
fi

echo "[OK] feature workflow entry ready: $FEATURE_ID"
