#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"
ACTIVE_SESSION_FILE="$ROOT_DIR/.context/active_session"

STAGE_CLOSEOUT=1
SESSION_FILE=""
FEATURE_ID="${1:-}"
SUMMARY="${2:-}"
NEXT_STEP="${3:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-stage-closeout)
      STAGE_CLOSEOUT=0
      shift
      ;;
    -h|--help)
      echo "Usage: scripts/complete-feature.sh [--no-stage-closeout] <feature-id> \"<summary>\" \"<next-step>\""
      echo "Or set .context/active_feature first."
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

FEATURE_ID="${1:-}"
SUMMARY="${2:-}"
NEXT_STEP="${3:-}"

if [[ -z "$FEATURE_ID" && -f "$ACTIVE_FEATURE_FILE" ]]; then
  FEATURE_ID="$(tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE")"
fi

if [[ -z "$FEATURE_ID" ]]; then
  echo "Usage: scripts/complete-feature.sh [--no-stage-closeout] <feature-id> \"<summary>\" \"<next-step>\""
  echo "Or set .context/active_feature first."
  exit 1
fi

if [[ -z "$SUMMARY" || -z "$NEXT_STEP" ]]; then
  echo "Usage: scripts/complete-feature.sh [--no-stage-closeout] <feature-id> \"<summary>\" \"<next-step>\""
  exit 1
fi

if [[ ! -d "$ROOT_DIR/docs/features/$FEATURE_ID" ]]; then
  echo "[ERROR] feature packet not found: docs/features/$FEATURE_ID"
  exit 1
fi

"$ROOT_DIR/scripts/set-active-feature.sh" "$FEATURE_ID"
"$ROOT_DIR/scripts/gates/run.sh" --reuse-if-valid "$FEATURE_ID"

if [[ ! -s "$ACTIVE_SESSION_FILE" ]]; then
  "$ROOT_DIR/scripts/context-log.sh" start "complete-$FEATURE_ID"
fi

if [[ -s "$ACTIVE_SESSION_FILE" ]]; then
  SESSION_FILE="$(tr -d '\r' < "$ACTIVE_SESSION_FILE")"
fi

"$ROOT_DIR/scripts/context-log.sh" note "Feature $FEATURE_ID completed. All gates passed."
"$ROOT_DIR/scripts/context-log.sh" finish "$SUMMARY" "$NEXT_STEP"

if [[ "$STAGE_CLOSEOUT" == "1" ]]; then
  if [[ -n "$SESSION_FILE" ]]; then
    "$ROOT_DIR/scripts/stage-closeout.sh" --feature "$FEATURE_ID" --session-file "$SESSION_FILE"
  else
    "$ROOT_DIR/scripts/stage-closeout.sh" --feature "$FEATURE_ID"
  fi
fi

echo "[PASS] feature completion recorded: $FEATURE_ID"
