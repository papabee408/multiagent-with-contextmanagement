#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FEATURE_ID=""
MODE_VALUE=""
RATIONALE_VALUE=""

usage() {
  cat <<'EOF'
Usage:
  scripts/promote-workflow.sh [--feature <feature-id>] <trivial|lite|full> [--reason "<why this promotion is needed>"]
EOF
}

mode_rank() {
  case "${1:-}" in
    trivial)
      printf '1'
      ;;
    lite)
      printf '2'
      ;;
    full)
      printf '3'
      ;;
    *)
      printf '0'
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      FEATURE_ID="${2:-}"
      if [[ -z "$FEATURE_ID" ]]; then
        echo "[ERROR] --feature requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --reason)
      RATIONALE_VALUE="${2:-}"
      if [[ -z "$RATIONALE_VALUE" ]]; then
        echo "[ERROR] --reason requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$MODE_VALUE" ]]; then
        MODE_VALUE="$1"
        shift
      else
        echo "[ERROR] unexpected argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$MODE_VALUE" ]]; then
  usage
  exit 1
fi

FEATURE_ID="${FEATURE_ID:-}"
if [[ -z "$FEATURE_ID" && -f "$ROOT_DIR/.context/active_feature" ]]; then
  FEATURE_ID="$(tr -d ' \n\r\t' < "$ROOT_DIR/.context/active_feature")"
fi

if [[ -z "$FEATURE_ID" ]]; then
  echo "[ERROR] feature-id is required" >&2
  exit 1
fi

source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"
current_mode="$(workflow_mode_from_brief)"

case "$MODE_VALUE" in
  trivial|lite|full)
    ;;
  *)
    echo "[ERROR] workflow mode must be trivial, lite, or full" >&2
    exit 1
    ;;
esac

if [[ -n "$current_mode" ]] && (( $(mode_rank "$MODE_VALUE") <= $(mode_rank "$current_mode") )); then
  echo "[ERROR] promote-workflow.sh only allows upward changes ($current_mode -> $MODE_VALUE is not a promotion)" >&2
  exit 1
fi

workflow_cmd=(bash "$ROOT_DIR/scripts/workflow-mode.sh" set --feature "$FEATURE_ID" --allow-change "$MODE_VALUE")
if [[ -n "$RATIONALE_VALUE" ]]; then
  workflow_cmd+=(--reason "$RATIONALE_VALUE")
fi

"${workflow_cmd[@]}"
bash "$ROOT_DIR/scripts/sync-handoffs.sh" "$FEATURE_ID"
echo "[OK] workflow promoted in-place: $FEATURE_ID -> $MODE_VALUE"
