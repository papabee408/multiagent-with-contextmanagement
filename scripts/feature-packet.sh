#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_git_change_helpers.sh"
TEMPLATE_DIR="$ROOT_DIR/docs/features/_template"
FEATURES_DIR="$ROOT_DIR/docs/features"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"

usage() {
  echo "Usage: scripts/feature-packet.sh [--risk-class trivial|standard|high-risk] [--risk-rationale \"<why>\"] [--workflow-mode trivial|lite|full] [--workflow-reason \"<why>\"] [--execution-mode single|multi-agent] [--execution-reason \"<why>\"] <feature-id>"
  echo "Example: scripts/feature-packet.sh --risk-class high-risk --execution-mode single feature-42-copy-fix"
}

RISK_CLASS=""
RISK_RATIONALE=""
WORKFLOW_MODE=""
WORKFLOW_REASON=""
EXECUTION_MODE=""
EXECUTION_REASON=""

replace_brief_key_or_exit() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local tmp_file

  tmp_file="$(mktemp)"

  awk -v section="$section" -v key="$key" -v value="$value" '
    $0 == section { in_section = 1 }
    /^## / && in_section && $0 != section { in_section = 0 }
    in_section {
      prefix = "- " key ":"
      if (index($0, prefix) == 1) {
        print prefix " " value
        replaced = 1
        next
      }
    }
    { print }
    END {
      if (!replaced) {
        exit 7
      }
    }
  ' "$file" > "$tmp_file" || {
    rm -f "$tmp_file"
    echo "[ERROR] missing brief field '$key' in $file" >&2
    exit 1
  }

  mv "$tmp_file" "$file"
}

default_risk_rationale() {
  case "${1:-}" in
    trivial)
      printf '%s' "tiny, low-risk work can use the lightest workflow path"
      ;;
    high-risk)
      printf '%s' "change touches high-risk behavior and must start in the full workflow"
      ;;
    *)
      printf '%s' "default product work keeps tester verification while avoiding reviewer/security overhead"
      ;;
  esac
}

default_workflow_reason() {
  case "${1:-}" in
    trivial)
      printf '%s' "tiny, low-risk path that stops at gate-checker"
      ;;
    full)
      printf '%s' "higher-risk change keeps reviewer and security required from the start"
      ;;
    *)
      printf '%s' "balanced default path with tester verification and no reviewer/security stage"
      ;;
  esac
}

default_execution_reason() {
  case "${1:-}" in
    multi-agent)
      printf '%s' "independent role ownership or explicit parallel work is worth the coordination overhead"
      ;;
    *)
      printf '%s' "one lead agent owns the feature end-to-end; helper sub-agents stay optional and bounded"
      ;;
  esac
}

normalize_mode_token_local() {
  local value="${1:-}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  case "$value" in
    single|multi-agent|trivial|lite|full)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

normalize_risk_class_token_local() {
  local value="${1:-}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
  case "$value" in
    trivial|standard|high-risk)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

prevalidate_bootstrap_inputs() {
  local normalized_value=""

  if [[ -n "$RISK_CLASS" ]]; then
    normalized_value="$(normalize_risk_class_token_local "$RISK_CLASS")"
    if [[ -z "$normalized_value" ]]; then
      echo "[ERROR] risk class must be trivial, standard, or high-risk" >&2
      exit 1
    fi
    RISK_CLASS="$normalized_value"
  fi

  if [[ -n "$WORKFLOW_MODE" ]]; then
    normalized_value="$(normalize_mode_token_local "$WORKFLOW_MODE")"
    case "$normalized_value" in
      trivial|lite|full)
        WORKFLOW_MODE="$normalized_value"
        ;;
      *)
        echo "[ERROR] workflow mode must be trivial, lite, or full" >&2
        exit 1
        ;;
    esac
  fi

  if [[ -n "$EXECUTION_MODE" ]]; then
    normalized_value="$(normalize_mode_token_local "$EXECUTION_MODE")"
    case "$normalized_value" in
      single|multi-agent)
        EXECUTION_MODE="$normalized_value"
        ;;
      *)
        echo "[ERROR] execution mode must be single or multi-agent" >&2
        exit 1
        ;;
    esac
  fi

  if [[ "$RISK_CLASS" == "high-risk" && -n "$WORKFLOW_MODE" && "$WORKFLOW_MODE" != "full" ]]; then
    echo "[ERROR] high-risk features must start in workflow mode full" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --risk-class)
      RISK_CLASS="${2:-}"
      shift 2
      ;;
    --risk-rationale)
      RISK_RATIONALE="${2:-}"
      shift 2
      ;;
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

prevalidate_bootstrap_inputs

git_changed_files_for_repo "$ROOT_DIR" "${GATE_DIFF_RANGE:-}" "${GITHUB_BASE_REF:-}" > "$BASELINE_TMP_FILE"

mkdir -p "$TARGET_DIR"
cp "$TEMPLATE_DIR/brief.md" "$TARGET_DIR/brief.md"
cp "$TEMPLATE_DIR/plan.md" "$TARGET_DIR/plan.md"
cp "$TEMPLATE_DIR/test-matrix.md" "$TARGET_DIR/test-matrix.md"
cp "$TEMPLATE_DIR/run-log.md" "$TARGET_DIR/run-log.md"

for file in "$TARGET_DIR"/*.md; do
  perl -0pi -e 's/(?m)^- `feature-id`:\s*.*$/- `feature-id`: '"$FEATURE_ID"'/g' "$file"
  perl -0pi -e 's/(?m)^- feature-id:\s*.*$/- feature-id: '"$FEATURE_ID"'/g' "$file"
done

mv "$BASELINE_TMP_FILE" "$BASELINE_FILE"
trap - EXIT

echo "[OK] feature packet created: docs/features/$FEATURE_ID"
echo "$FEATURE_ID" > "$ACTIVE_FEATURE_FILE"
echo "[OK] active feature set: $FEATURE_ID"

source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"

if [[ -z "$RISK_CLASS" ]]; then
  RISK_CLASS="standard"
fi

RISK_CLASS="$(normalize_risk_class_token "$RISK_CLASS")"
if [[ -z "$RISK_CLASS" ]]; then
  echo "[ERROR] risk class must be trivial, standard, or high-risk" >&2
  exit 1
fi

if [[ -z "$RISK_RATIONALE" ]]; then
  RISK_RATIONALE="$(default_risk_rationale "$RISK_CLASS")"
fi

replace_brief_key_or_exit "$TARGET_DIR/brief.md" "## Risk Class" "class" "\`$RISK_CLASS\`"
replace_brief_key_or_exit "$TARGET_DIR/brief.md" "## Risk Class" "rationale" "$RISK_RATIONALE"

if [[ -z "$WORKFLOW_MODE" ]]; then
  WORKFLOW_MODE="$(default_workflow_mode_for_risk_class "$RISK_CLASS")"
fi

if [[ "$RISK_CLASS" == "high-risk" && "$WORKFLOW_MODE" != "full" ]]; then
  echo "[ERROR] high-risk features must start in workflow mode full" >&2
  exit 1
fi

if [[ -z "$WORKFLOW_REASON" ]]; then
  WORKFLOW_REASON="$(default_workflow_reason "$WORKFLOW_MODE")"
fi

if [[ -z "$EXECUTION_MODE" ]]; then
  EXECUTION_MODE="single"
fi

if [[ -z "$EXECUTION_REASON" ]]; then
  EXECUTION_REASON="$(default_execution_reason "$EXECUTION_MODE")"
fi

workflow_cmd=(bash "$ROOT_DIR/scripts/workflow-mode.sh" set --feature "$FEATURE_ID" "$WORKFLOW_MODE")
workflow_cmd+=(--reason "$WORKFLOW_REASON")
"${workflow_cmd[@]}"

execution_cmd=(bash "$ROOT_DIR/scripts/execution-mode.sh" set --feature "$FEATURE_ID" "$EXECUTION_MODE")
execution_cmd+=(--reason "$EXECUTION_REASON")
"${execution_cmd[@]}"

bash "$ROOT_DIR/scripts/sync-handoffs.sh" "$FEATURE_ID"
