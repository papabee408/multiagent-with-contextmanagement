#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/docs/features/_template"
FEATURES_DIR="$ROOT_DIR/docs/features"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"

usage() {
  echo "Usage: scripts/feature-packet.sh [--workflow-mode lite|full] [--workflow-reason \"<why>\"] <feature-id>"
  echo "Example: scripts/feature-packet.sh --workflow-mode lite feature-42-ia-flow"
}

WORKFLOW_MODE=""
WORKFLOW_REASON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflow-mode)
      WORKFLOW_MODE="${2:-}"
      shift 2
      ;;
    --workflow-reason)
      WORKFLOW_REASON="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

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
cp "$TEMPLATE_DIR/implementer-handoff.md" "$TARGET_DIR/implementer-handoff.md"
cp "$TEMPLATE_DIR/tester-handoff.md" "$TARGET_DIR/tester-handoff.md"
cp "$TEMPLATE_DIR/reviewer-handoff.md" "$TARGET_DIR/reviewer-handoff.md"
cp "$TEMPLATE_DIR/security-handoff.md" "$TARGET_DIR/security-handoff.md"
cp "$TEMPLATE_DIR/test-matrix.md" "$TARGET_DIR/test-matrix.md"
cp "$TEMPLATE_DIR/run-log.md" "$TARGET_DIR/run-log.md"

# Fill feature id placeholder
for file in "$TARGET_DIR"/*.md; do
  tmp_file="$(mktemp)"
  sed "s/feature-id/$FEATURE_ID/g" "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
done

"$ROOT_DIR/scripts/sync-handoffs.sh" "$FEATURE_ID"

# Snapshot current dirty files as baseline so gates can ignore pre-existing changes.
{
  git -C "$ROOT_DIR" diff --name-only --relative
  git -C "$ROOT_DIR" diff --name-only --relative --cached
  git -C "$ROOT_DIR" ls-files --others --exclude-standard
} | sed '/^$/d' | sort -u > "$BASELINE_FILE"

echo "[OK] feature packet created: docs/features/$FEATURE_ID"
echo "$FEATURE_ID" > "$ACTIVE_FEATURE_FILE"
echo "[OK] active feature set: $FEATURE_ID"

if [[ -n "$WORKFLOW_MODE" ]]; then
  if [[ -n "$WORKFLOW_REASON" ]]; then
    "$ROOT_DIR/scripts/workflow-mode.sh" set --feature "$FEATURE_ID" "$WORKFLOW_MODE" --reason "$WORKFLOW_REASON"
  else
    "$ROOT_DIR/scripts/workflow-mode.sh" set --feature "$FEATURE_ID" "$WORKFLOW_MODE"
  fi
fi
