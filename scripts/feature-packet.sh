#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/docs/features/_template"
FEATURES_DIR="$ROOT_DIR/docs/features"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"

usage() {
  echo "Usage: scripts/feature-packet.sh <feature-id>"
  echo "Example: scripts/feature-packet.sh feature-42-ia-flow"
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

FEATURE_ID="$1"
TARGET_DIR="$FEATURES_DIR/$FEATURE_ID"
BASELINE_FILE="$TARGET_DIR/.baseline-changes.txt"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "[ERROR] template dir not found: $TEMPLATE_DIR"
  exit 1
fi

if [[ -e "$TARGET_DIR" ]]; then
  echo "[ERROR] feature packet already exists: $TARGET_DIR"
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$TEMPLATE_DIR/brief.md" "$TARGET_DIR/brief.md"
cp "$TEMPLATE_DIR/plan.md" "$TARGET_DIR/plan.md"
cp "$TEMPLATE_DIR/test-matrix.md" "$TARGET_DIR/test-matrix.md"
cp "$TEMPLATE_DIR/run-log.md" "$TARGET_DIR/run-log.md"

# Fill feature id placeholder
for file in "$TARGET_DIR"/*.md; do
  tmp_file="$(mktemp)"
  sed "s/feature-id/$FEATURE_ID/g" "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
done

# Snapshot current dirty files as baseline so gates can ignore pre-existing changes.
{
  git -C "$ROOT_DIR" diff --name-only --relative
  git -C "$ROOT_DIR" diff --name-only --relative --cached
  git -C "$ROOT_DIR" ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u > "$BASELINE_FILE"

echo "[OK] feature packet created: docs/features/$FEATURE_ID"
echo "$FEATURE_ID" > "$ACTIVE_FEATURE_FILE"
echo "[OK] active feature set: $FEATURE_ID"
