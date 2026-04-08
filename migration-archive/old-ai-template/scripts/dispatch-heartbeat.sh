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
  scripts/dispatch-heartbeat.sh guard [--feature <feature-id>]
  scripts/dispatch-heartbeat.sh show [--feature <feature-id>]
EOF
}

now_epoch() {
  if [[ -n "${DISPATCH_HEARTBEAT_NOW_EPOCH:-}" ]]; then
    printf '%s' "$DISPATCH_HEARTBEAT_NOW_EPOCH"
    return
  fi

  perl -e 'print time()'
}

format_utc_from_epoch() {
  perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M:%SZ", gmtime($ARGV[0]))' "${1:-0}"
}

now_utc() {
  format_utc_from_epoch "$(now_epoch)"
}

risk_threshold_seconds() {
  printf '%s' "${DISPATCH_HEARTBEAT_RISK_SECONDS:-45}"
}

interrupt_threshold_seconds() {
  printf '%s' "${DISPATCH_HEARTBEAT_INTERRUPT_SECONDS:-120}"
}

seconds_after_now_utc() {
  local offset="${1:-0}"
  format_utc_from_epoch "$(( $(now_epoch) + offset ))"
}

utc_to_epoch() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    printf '%s' ""
    return
  fi

  perl -MTime::Piece -e '
    my $value = shift;
    my $epoch = Time::Piece->strptime($value, "%Y-%m-%d %H:%M:%SZ")->epoch;
    print $epoch;
  ' "$value" 2>/dev/null || printf '%s' ""
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

refresh_idle_deadline_utc() {
  seconds_after_now_utc "$(interrupt_threshold_seconds)"
}

existing_started_at_value() {
  local run_log="$1"
  local now="$2"
  local started_at

  started_at="$(monitor_field_value "$run_log" "started-at-utc")"
  started_at="$(trim "$started_at")"
  if [[ -z "$started_at" ]]; then
    started_at="$now"
  fi

  printf '%s' "$started_at"
}

set_monitor_state() {
  local run_log="$1"
  local role="$2"
  local status="$3"
  local started_at="$4"
  local last_progress_at="$5"
  local interrupt_after="$6"
  local message="$7"

  update_monitor_field "$run_log" "current-role" "$role"
  update_monitor_field "$run_log" "current-status" "\`$status\`"
  update_monitor_field "$run_log" "started-at-utc" "$started_at"
  update_monitor_field "$run_log" "last-progress-at-utc" "$last_progress_at"
  update_monitor_field "$run_log" "interrupt-after-utc" "$interrupt_after"
  update_monitor_field "$run_log" "last-progress" "$message"
}

update_monitor() {
  local command="$1"
  local role="$2"
  local message="$3"
  local feature_id="$4"
  local run_log
  local status
  local now
  local started_at
  local interrupt_after
  local readiness_output

  validate_role "$role"
  run_log="$(ensure_run_log "$feature_id")"
  now="$(now_utc)"
  message="$(normalize_line "$message")"

  if [[ "$role" == "implementer" && ( "$command" == "queue" || "$command" == "start" ) ]]; then
    if ! readiness_output="$(bash "$ROOT_DIR/scripts/gates/check-implementer-ready.sh" --feature "$feature_id" 2>&1)"; then
      if [[ -n "$readiness_output" ]]; then
        printf '%s\n' "$readiness_output" >&2
      fi
      echo "[ERROR] implementer dispatch blocked: brief, plan, and synced handoffs must pass before code edits" >&2
      exit 1
    fi
  fi

  case "$command" in
    queue)
      status="QUEUED"
      started_at=""
      interrupt_after=""
      ;;
    start)
      status="RUNNING"
      started_at="$now"
      interrupt_after="$(refresh_idle_deadline_utc)"
      ;;
    progress)
      status="RUNNING"
      started_at="$(existing_started_at_value "$run_log" "$now")"
      interrupt_after="$(refresh_idle_deadline_utc)"
      ;;
    risk)
      status="AT_RISK"
      started_at="$(existing_started_at_value "$run_log" "$now")"
      interrupt_after="$(refresh_idle_deadline_utc)"
      ;;
    blocked)
      status="BLOCKED"
      started_at="$(existing_started_at_value "$run_log" "$now")"
      interrupt_after="$(refresh_idle_deadline_utc)"
      ;;
    done)
      status="DONE"
      started_at="$(existing_started_at_value "$run_log" "$now")"
      interrupt_after="$(refresh_idle_deadline_utc)"
      ;;
    *)
      echo "[ERROR] unsupported command: $command" >&2
      exit 1
      ;;
  esac

  set_monitor_state \
    "$run_log" \
    "$role" \
    "$status" \
    "$started_at" \
    "$now" \
    "$interrupt_after" \
    "$message"

  show_monitor "$feature_id"
}

guard_monitor() {
  local feature_id="$1"
  local run_log
  local status
  local role
  local started_at
  local last_progress_at
  local last_progress
  local last_progress_epoch
  local now_epoch_value
  local age_seconds
  local interrupt_after

  run_log="$(ensure_run_log "$feature_id")"
  role="$(trim "$(monitor_field_value "$run_log" "current-role")")"
  status="$(trim "$(monitor_field_value "$run_log" "current-status")")"
  started_at="$(trim "$(monitor_field_value "$run_log" "started-at-utc")")"
  last_progress_at="$(trim "$(monitor_field_value "$run_log" "last-progress-at-utc")")"
  last_progress="$(normalize_line "$(monitor_field_value "$run_log" "last-progress")")"

  case "$status" in
    ""|QUEUED|DONE|BLOCKED)
      show_monitor "$feature_id"
      return
      ;;
    RUNNING|AT_RISK)
      ;;
    *)
      show_monitor "$feature_id"
      return
      ;;
  esac

  if [[ -z "$role" || -z "$started_at" || -z "$last_progress_at" ]]; then
    show_monitor "$feature_id"
    return
  fi

  last_progress_epoch="$(utc_to_epoch "$last_progress_at")"
  if [[ -z "$last_progress_epoch" ]]; then
    show_monitor "$feature_id"
    return
  fi

  now_epoch_value="$(now_epoch)"
  age_seconds="$(( now_epoch_value - last_progress_epoch ))"
  interrupt_after="$(format_utc_from_epoch "$(( last_progress_epoch + $(interrupt_threshold_seconds) ))")"
  update_monitor_field "$run_log" "interrupt-after-utc" "$interrupt_after"

  if (( age_seconds >= $(interrupt_threshold_seconds) )); then
    update_monitor_field "$run_log" "current-status" "\`BLOCKED\`"
  elif (( age_seconds >= $(risk_threshold_seconds) )) && [[ "$status" == "RUNNING" ]]; then
    update_monitor_field "$run_log" "current-status" "\`AT_RISK\`"
  fi

  if [[ -n "$last_progress" ]]; then
    update_monitor_field "$run_log" "last-progress" "$last_progress"
  fi

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
    guard)
      guard_monitor "$FEATURE_ID"
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
