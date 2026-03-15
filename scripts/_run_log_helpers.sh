#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"

trim_line() {
  local value="${1:-}"
  printf '%s' "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

normalize_line() {
  local value="${1:-}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="$(printf '%s' "$value" | tr -s ' ')"
  trim_line "$value"
}

resolve_feature_id_or_exit() {
  local feature_id="${1:-}"

  if [[ -z "$feature_id" && -f "$ACTIVE_FEATURE_FILE" ]]; then
    feature_id="$(tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE")"
  fi

  if [[ -z "$feature_id" ]]; then
    echo "[ERROR] feature-id is required. Set .context/active_feature or pass --feature." >&2
    exit 1
  fi

  printf '%s' "$feature_id"
}

validate_role_or_exit() {
  local role="$1"

  case "$role" in
    orchestrator|planner|implementer|tester|gate-checker|reviewer|security)
      ;;
    *)
      echo "[ERROR] invalid role: $role" >&2
      exit 1
      ;;
  esac
}

ensure_run_log_or_exit() {
  local feature_id="$1"
  local run_log="$ROOT_DIR/docs/features/$feature_id/run-log.md"

  if [[ ! -f "$run_log" ]]; then
    echo "[ERROR] run-log not found: docs/features/$feature_id/run-log.md" >&2
    exit 1
  fi

  printf '%s' "$run_log"
}

replace_role_section_or_exit() {
  local run_log="$1"
  local role="$2"
  local block_file="$3"
  local tmp_file

  tmp_file="$(mktemp)"

  awk -v role="$role" -v block_file="$block_file" '
    BEGIN {
      while ((getline line < block_file) > 0) {
        block[++count] = line
      }
      close(block_file)
    }
    $0 == "### " role {
      print
      for (i = 1; i <= count; i++) {
        print block[i]
      }
      replaced = 1
      in_role = 1
      next
    }
    in_role && /^### / {
      in_role = 0
    }
    !in_role {
      print
    }
    END {
      if (!replaced) {
        exit 7
      }
    }
  ' "$run_log" > "$tmp_file" || {
    rm -f "$tmp_file"
    echo "[ERROR] role section not found in run-log: $role" >&2
    exit 1
  }

  mv "$tmp_file" "$run_log"
}
