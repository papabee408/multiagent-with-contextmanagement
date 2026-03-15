#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_run_log_helpers.sh"

FEATURE_ID=""

usage() {
  cat <<'EOF'
Usage:
  scripts/dispatch-role.sh [--feature <feature-id>] <role> "<next action>"
EOF
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

FEATURE_ID="$(resolve_feature_id_or_exit "$FEATURE_ID")"
validate_role_or_exit "$ROLE"

"$ROOT_DIR/scripts/dispatch-heartbeat.sh" queue --feature "$FEATURE_ID" "$ROLE" "$(normalize_line "$MESSAGE")"
