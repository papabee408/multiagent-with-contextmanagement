#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_run_log_helpers.sh"

FEATURE_ID=""
MODE_VALUE=""
RATIONALE_VALUE=""

usage() {
  cat <<'EOF'
Usage:
  scripts/workflow-mode.sh show [--feature <feature-id>]
  scripts/workflow-mode.sh role-sequence [--feature <feature-id>]
  scripts/workflow-mode.sh set [--feature <feature-id>] <lite|full> [--reason "<why this mode fits>"]
EOF
}

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
    echo "[ERROR] missing workflow mode field '$key' in $file" >&2
    exit 1
  }

  mv "$tmp_file" "$file"
}

current_reason_or_default() {
  local feature_id="$1"
  local brief_file="$ROOT_DIR/docs/features/$feature_id/brief.md"
  local current_reason=""

  source "$ROOT_DIR/scripts/gates/_helpers.sh" "$feature_id"
  current_reason="$(workflow_rationale_from_brief)"
  if is_placeholder_text "$current_reason"; then
    printf '%s' "selected during feature bootstrap"
    return 0
  fi

  printf '%s' "$current_reason"
}

COMMAND="${1:-}"
if [[ -z "$COMMAND" ]]; then
  usage
  exit 1
fi
shift || true

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
      if [[ "$COMMAND" == "set" && -z "$MODE_VALUE" ]]; then
        MODE_VALUE="$1"
        shift
      else
        echo "[ERROR] unexpected argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

FEATURE_ID="$(resolve_feature_id_or_exit "$FEATURE_ID")"
source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"

BRIEF_FILE="$ROOT_DIR/docs/features/$FEATURE_ID/brief.md"
if [[ ! -f "$BRIEF_FILE" ]]; then
  echo "[ERROR] brief file not found: $BRIEF_FILE" >&2
  exit 1
fi

case "$COMMAND" in
  show)
    printf '%s\n' "$(workflow_mode_from_brief)"
    ;;
  role-sequence)
    workflow_roles_for_mode "$(workflow_mode_from_brief)"
    ;;
  set)
    MODE_VALUE="$(normalize_mode_token "$MODE_VALUE")"
    if [[ -z "$MODE_VALUE" ]]; then
      usage
      exit 1
    fi
    case "$MODE_VALUE" in
      lite|full)
        ;;
      *)
        echo "[ERROR] workflow mode must be lite or full" >&2
        exit 1
        ;;
    esac

    if [[ -z "$RATIONALE_VALUE" ]]; then
      RATIONALE_VALUE="$(current_reason_or_default "$FEATURE_ID")"
    fi

    replace_brief_key_or_exit "$BRIEF_FILE" "## Workflow Mode" "mode" "\`$MODE_VALUE\`"
    replace_brief_key_or_exit "$BRIEF_FILE" "## Workflow Mode" "rationale" "$RATIONALE_VALUE"
    echo "[OK] workflow mode set: $FEATURE_ID -> $MODE_VALUE"
    ;;
  *)
    usage
    exit 1
    ;;
esac
