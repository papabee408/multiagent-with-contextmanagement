#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_run_log_helpers.sh"

FEATURE_ID=""
MODE_VALUE=""
RATIONALE_VALUE=""
ALLOW_CHANGE=0

usage() {
  cat <<'EOF'
Usage:
  scripts/execution-mode.sh show [--feature <feature-id>]
  scripts/execution-mode.sh set [--feature <feature-id>] [--allow-change] <single|multi-agent> [--reason "<why this mode fits>"]
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
    echo "[ERROR] missing execution mode field '$key' in $file" >&2
    exit 1
  }

  mv "$tmp_file" "$file"
}

default_reason_for_mode() {
  case "${1:-}" in
    single)
      printf '%s' "one lead agent owns the feature end-to-end; helper sub-agents stay optional and bounded"
      ;;
    multi-agent)
      printf '%s' "independent role ownership or explicit parallel work is worth the coordination overhead"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

current_mode_is_locked() {
  local current_mode="$1"
  [[ -n "$current_mode" ]]
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
    --allow-change)
      ALLOW_CHANGE=1
      shift
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
    printf '%s\n' "$(execution_mode_from_brief)"
    ;;
  set)
    MODE_VALUE="$(normalize_mode_token "$MODE_VALUE")"
    case "$MODE_VALUE" in
      single|multi-agent)
        ;;
      *)
        echo "[ERROR] execution mode must be single or multi-agent" >&2
        exit 1
        ;;
    esac

    current_mode="$(execution_mode_from_brief)"
    if current_mode_is_locked "$current_mode" && [[ "$current_mode" != "$MODE_VALUE" && "$ALLOW_CHANGE" != "1" ]]; then
      echo "[ERROR] execution mode is locked after bootstrap. Use --allow-change only when the user explicitly approved a mode change." >&2
      exit 1
    fi

    if [[ -z "$RATIONALE_VALUE" ]]; then
      RATIONALE_VALUE="$(default_reason_for_mode "$MODE_VALUE")"
    fi

    replace_brief_key_or_exit "$BRIEF_FILE" "## Execution Mode" "mode" "\`$MODE_VALUE\`"
    replace_brief_key_or_exit "$BRIEF_FILE" "## Execution Mode" "rationale" "$RATIONALE_VALUE"
    echo "[OK] execution mode set: $FEATURE_ID -> $MODE_VALUE"
    ;;
  *)
    usage
    exit 1
    ;;
esac
