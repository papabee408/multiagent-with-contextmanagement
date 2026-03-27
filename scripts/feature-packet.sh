#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_git_change_helpers.sh"
TEMPLATE_DIR="$ROOT_DIR/docs/features/_template"
FEATURES_DIR="$ROOT_DIR/docs/features"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"

usage() {
  echo "Usage: scripts/feature-packet.sh [--workflow-mode trivial|lite|full] [--workflow-reason \"<why>\"] [--execution-mode single|multi-agent] [--execution-reason \"<why>\"] <feature-id>"
  echo "Example: scripts/feature-packet.sh --workflow-mode lite --execution-mode single feature-42-copy-fix"
}

WORKFLOW_MODE=""
WORKFLOW_REASON=""
EXECUTION_MODE=""
EXECUTION_REASON=""

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
    --execution-mode)
      EXECUTION_MODE="${2:-}"
      shift 2
      ;;
    --execution-reason)
      EXECUTION_REASON="${2:-}"
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

if [[ -z "${1:-}" ]]; then
  usage
  exit 1
fi

FEATURE_ID="$1"
TARGET_DIR="$FEATURES_DIR/$FEATURE_ID"
BASELINE_FILE="$TARGET_DIR/.baseline-changes.txt"
BASELINE_TMP_FILE="$(mktemp)"
trap 'rm -f "$BASELINE_TMP_FILE"' EXIT

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "[ERROR] template dir not found: $TEMPLATE_DIR"
  exit 1
fi

if [[ -e "$TARGET_DIR" ]]; then
  echo "[ERROR] feature packet already exists: $TARGET_DIR"
  exit 1
fi

git_changed_files_for_repo "$ROOT_DIR" "${GATE_DIFF_RANGE:-}" "${GITHUB_BASE_REF:-}" > "$BASELINE_TMP_FILE"

mkdir -p "$TARGET_DIR"
cp "$TEMPLATE_DIR/brief.md" "$TARGET_DIR/brief.md"
cp "$TEMPLATE_DIR/plan.md" "$TARGET_DIR/plan.md"
cp "$TEMPLATE_DIR/implementer-handoff.md" "$TARGET_DIR/implementer-handoff.md"
cp "$TEMPLATE_DIR/tester-handoff.md" "$TARGET_DIR/tester-handoff.md"
cp "$TEMPLATE_DIR/reviewer-handoff.md" "$TARGET_DIR/reviewer-handoff.md"
cp "$TEMPLATE_DIR/security-handoff.md" "$TARGET_DIR/security-handoff.md"
cp "$TEMPLATE_DIR/test-matrix.md" "$TARGET_DIR/test-matrix.md"
cp "$TEMPLATE_DIR/run-log.md" "$TARGET_DIR/run-log.md"

for file in "$TARGET_DIR"/*.md; do
  tmp_file="$(mktemp)"
  sed "s/feature-id/$FEATURE_ID/g" "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
done

mv "$BASELINE_TMP_FILE" "$BASELINE_FILE"
trap - EXIT

echo "[OK] feature packet created: docs/features/$FEATURE_ID"
echo "$FEATURE_ID" > "$ACTIVE_FEATURE_FILE"
echo "[OK] active feature set: $FEATURE_ID"

if [[ -z "$WORKFLOW_MODE" ]]; then
  WORKFLOW_MODE="lite"
fi

if [[ -z "$EXECUTION_MODE" ]]; then
  EXECUTION_MODE="single"
fi

workflow_cmd=(bash "$ROOT_DIR/scripts/workflow-mode.sh" set --feature "$FEATURE_ID" "$WORKFLOW_MODE")
if [[ -n "$WORKFLOW_REASON" ]]; then
  workflow_cmd+=(--reason "$WORKFLOW_REASON")
fi
"${workflow_cmd[@]}"

execution_cmd=(bash "$ROOT_DIR/scripts/execution-mode.sh" set --feature "$FEATURE_ID" "$EXECUTION_MODE")
if [[ -n "$EXECUTION_REASON" ]]; then
  execution_cmd+=(--reason "$EXECUTION_REASON")
fi
"${execution_cmd[@]}"

bash "$ROOT_DIR/scripts/sync-handoffs.sh" "$FEATURE_ID"
