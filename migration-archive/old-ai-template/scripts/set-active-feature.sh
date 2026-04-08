#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURE_ID="${1:-}"

if [[ -z "$FEATURE_ID" ]]; then
  echo "Usage: scripts/set-active-feature.sh <feature-id>"
  exit 1
fi

if [[ ! -d "$ROOT_DIR/docs/features/$FEATURE_ID" ]]; then
  echo "[ERROR] feature packet not found: docs/features/$FEATURE_ID"
  exit 1
fi

echo "$FEATURE_ID" > "$ROOT_DIR/.context/active_feature"
echo "[OK] active feature set: $FEATURE_ID"
