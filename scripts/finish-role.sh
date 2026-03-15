#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_run_log_helpers.sh"

FEATURE_ID=""
NEXT_ROLE=""
NEXT_ACTION=""

usage() {
  cat <<'EOF'
Usage:
  scripts/finish-role.sh [--feature <feature-id>] <role> "<done message>" [--next-role <role> --next-action "<next action>"]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      FEATURE_ID="${2:-}"
      shift 2
      ;;
    --next-role)
      NEXT_ROLE="${2:-}"
      shift 2
      ;;
    --next-action)
      NEXT_ACTION="${2:-}"
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

ROLE="${1:-}"
MESSAGE="${2:-}"
if [[ -z "$ROLE" || -z "$MESSAGE" ]]; then
  usage
  exit 1
fi
shift 2 || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --next-role)
      NEXT_ROLE="${2:-}"
      shift 2
      ;;
    --next-action)
      NEXT_ACTION="${2:-}"
      shift 2
      ;;
    *)
      echo "[ERROR] unexpected argument: $1" >&2
      exit 1
      ;;
  esac
done

FEATURE_ID="$(resolve_feature_id_or_exit "$FEATURE_ID")"
validate_role_or_exit "$ROLE"

"$ROOT_DIR/scripts/dispatch-heartbeat.sh" done --feature "$FEATURE_ID" "$ROLE" "$(normalize_line "$MESSAGE")"

if [[ -n "$NEXT_ROLE" || -n "$NEXT_ACTION" ]]; then
  if [[ -z "$NEXT_ROLE" || -z "$NEXT_ACTION" ]]; then
    echo "[ERROR] --next-role and --next-action must be provided together" >&2
    exit 1
  fi
  validate_role_or_exit "$NEXT_ROLE"
  "$ROOT_DIR/scripts/dispatch-role.sh" --feature "$FEATURE_ID" "$NEXT_ROLE" "$(normalize_line "$NEXT_ACTION")"
fi
