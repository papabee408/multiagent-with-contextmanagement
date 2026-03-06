#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"
FEATURE_ID=""

usage() {
  cat <<'EOF'
Usage:
  scripts/dispatch-heartbeat.sh queue [--feature <feature-id>] <role> "<message>"
  scripts/dispatch-heartbeat.sh start [--feature <feature-id>] <role> "<message>"
  scripts/dispatch-heartbeat.sh progress [--feature <feature-id>] <role> "<message>"
  scripts/dispatch-heartbeat.sh risk [--feature <feature-id>] <role> "<message>"
  scripts/dispatch-heartbeat.sh blocked [--feature <feature-id>] <role> "<message>"
  scripts/dispatch-heartbeat.sh done [--feature <feature-id>] <role> "<message>"
  scripts/dispatch-heartbeat.sh show [--feature <feature-id>]
EOF
}

now_utc() {
  perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M:%SZ", gmtime(time()))'
}

interrupt_deadline_utc() {
  perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M:%SZ", gmtime(time() + 120))'
}

trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

normalize_line() {
  local value="$1"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="$(printf '%s' "$value" | tr -s ' ')"
  trim "$value"
}

resolve_feature_id() {
  if [[ -n "$FEATURE_ID" ]]; then
    printf '%s' "$FEATURE_ID"
    return
  fi

  if [[ -f "$ACTIVE_FEATURE_FILE" ]]; then
    tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE"
    return
  fi

  printf ''
}

validate_role() {
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

monitor_field_value() {
  local run_log="$1"
  local field="$2"

  awk -v field="$field" '
    $0 == "## Dispatch Monitor" { in_monitor = 1; next }
    in_monitor && /^## / { in_monitor = 0 }
    in_monitor {
      prefix = "- " field ":"
      if (index($0, prefix) == 1) {
        line = substr($0, length(prefix) + 1)
        gsub(/`/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$run_log"
}

ensure_run_log() {
  local feature_id="$1"
  local feature_dir="$ROOT_DIR/docs/features/$feature_id"
  local run_log="$feature_dir/run-log.md"

  if [[ -z "$feature_id" ]]; then
    echo "[ERROR] feature-id is required. Set .context/active_feature or pass --feature." >&2
    exit 1
  fi

  if [[ ! -f "$run_log" ]]; then
    echo "[ERROR] run-log not found: docs/features/$feature_id/run-log.md" >&2
    exit 1
  fi

  printf '%s' "$run_log"
}

update_monitor_field() {
  local run_log="$1"
  local field="$2"
  local value="$3"
  local tmp_file

  tmp_file="$(mktemp)"

  awk -v field="$field" -v value="$value" '
    BEGIN {
      replaced = 0
    }
    {
      prefix = "- " field ":"
      if (index($0, prefix) == 1) {
        print prefix " " value
        replaced = 1
        next
      }

      print
    }
    END {
      if (!replaced) {
        exit 7
      }
    }
  ' "$run_log" > "$tmp_file" || {
    rm -f "$tmp_file"
    echo "[ERROR] missing dispatch monitor field: $field" >&2
    exit 1
  }

  mv "$tmp_file" "$run_log"
}

update_monitor() {
  local command="$1"
  local role="$2"
  local message="$3"
  local feature_id="$4"
  local run_log
  local status
  local now
  local deadline
  local started_at

  validate_role "$role"
  run_log="$(ensure_run_log "$feature_id")"
  now="$(now_utc)"
  deadline="$(interrupt_deadline_utc)"
  message="$(normalize_line "$message")"

  case "$command" in
    queue)
      status="QUEUED"
      started_at="$now"
      ;;
    start|progress)
      status="RUNNING"
      started_at="$(monitor_field_value "$run_log" "started-at-utc")"
      started_at="$(trim "$started_at")"
      if [[ -z "$started_at" ]]; then
        started_at="$now"
      fi
      ;;
    risk)
      status="AT_RISK"
      started_at="$(monitor_field_value "$run_log" "started-at-utc")"
      started_at="$(trim "$started_at")"
      if [[ -z "$started_at" ]]; then
        started_at="$now"
      fi
      ;;
    blocked)
      status="BLOCKED"
      started_at="$(monitor_field_value "$run_log" "started-at-utc")"
      started_at="$(trim "$started_at")"
      if [[ -z "$started_at" ]]; then
        started_at="$now"
      fi
      ;;
    done)
      status="DONE"
      started_at="$(monitor_field_value "$run_log" "started-at-utc")"
      started_at="$(trim "$started_at")"
      if [[ -z "$started_at" ]]; then
        started_at="$now"
      fi
      ;;
    *)
      echo "[ERROR] unsupported command: $command" >&2
      exit 1
      ;;
  esac

  update_monitor_field "$run_log" "current-role" "$role"
  update_monitor_field "$run_log" "current-status" "\`$status\`"
  update_monitor_field "$run_log" "started-at-utc" "$started_at"
  update_monitor_field "$run_log" "last-progress-at-utc" "$now"
  update_monitor_field "$run_log" "interrupt-after-utc" "$deadline"
  update_monitor_field "$run_log" "last-progress" "$message"

  show_monitor "$feature_id"
}

show_monitor() {
  local feature_id="$1"
  local run_log

  run_log="$(ensure_run_log "$feature_id")"

  awk -v feature_id="$feature_id" '
    BEGIN {
      print "feature-id: " feature_id
    }
    $0 == "## Dispatch Monitor" { in_monitor = 1; next }
    in_monitor && /^## / { in_monitor = 0 }
    in_monitor && /^- / { print substr($0, 3) }
  ' "$run_log"
}

main() {
  local command="${1:-}"
  local role=""
  local message=""
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
      -h|--help)
        usage
        exit 0
        ;;
      *)
        break
        ;;
    esac
  done

  FEATURE_ID="$(resolve_feature_id)"

  case "$command" in
    queue|start|progress|risk|blocked|done)
      role="${1:-}"
      message="${2:-}"
      if [[ -z "$role" || -z "$message" ]]; then
        usage
        exit 1
      fi
      update_monitor "$command" "$role" "$message" "$FEATURE_ID"
      ;;
    show)
      show_monitor "$FEATURE_ID"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
