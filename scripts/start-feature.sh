#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURE_ID=""
WORKFLOW_MODE=""
WORKFLOW_REASON=""
PACKET_CREATED=0
SETUP_STAMP_FILE="$ROOT_DIR/.context/setup-check.done"

usage() {
  cat <<'EOF'
Usage:
  scripts/start-feature.sh [--workflow-mode lite|full] [--workflow-reason "<why>"] <feature-id>
EOF
}

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
      FEATURE_ID="${1:-}"
      shift
      ;;
  esac
done

if [[ -z "$FEATURE_ID" ]]; then
  usage
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
  if [[ -n "$WORKFLOW_MODE" && -n "$WORKFLOW_REASON" ]]; then
    "$ROOT_DIR/scripts/feature-packet.sh" --workflow-mode "$WORKFLOW_MODE" --workflow-reason "$WORKFLOW_REASON" "$FEATURE_ID"
  elif [[ -n "$WORKFLOW_MODE" ]]; then
    "$ROOT_DIR/scripts/feature-packet.sh" --workflow-mode "$WORKFLOW_MODE" "$FEATURE_ID"
  else
    "$ROOT_DIR/scripts/feature-packet.sh" "$FEATURE_ID"
  fi
  PACKET_CREATED=1
fi

if [[ "$PACKET_CREATED" != "1" && -d "$ROOT_DIR/docs/features/$FEATURE_ID" && -n "$WORKFLOW_MODE" ]]; then
  if [[ -n "$WORKFLOW_REASON" ]]; then
    "$ROOT_DIR/scripts/workflow-mode.sh" set --feature "$FEATURE_ID" "$WORKFLOW_MODE" --reason "$WORKFLOW_REASON"
  else
    "$ROOT_DIR/scripts/workflow-mode.sh" set --feature "$FEATURE_ID" "$WORKFLOW_MODE"
  fi
fi

echo "[OK] feature workflow entry ready: $FEATURE_ID"
