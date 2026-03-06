#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh" "${1:-}"

RUN_LOG="$FEATURE_DIR/run-log.md"

if [[ ! -f "$RUN_LOG" ]]; then
  echo "[FAIL] role-chain: run-log missing ($RUN_LOG)"
  exit 1
fi

roles=(
  "orchestrator"
  "planner"
  "implementer"
  "tester"
  "gate-checker"
  "reviewer"
  "security"
)

section_exists() {
  local role="$1"
  awk -v role="$role" '
    $0 == "### " role { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$RUN_LOG"
}

monitor_field_value() {
  local field="$1"

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
        found = 1
        exit
      }
    }
    END {
      if (!found) print ""
    }
  ' "$RUN_LOG"
}

field_value() {
  local role="$1"
  local field="$2"

  awk -v role="$role" -v field="$field" '
    $0 == "### " role { in_role = 1; next }
    in_role && /^### / { in_role = 0 }
    in_role {
      prefix = "- " field ":"
      if (index($0, prefix) == 1) {
        line = substr($0, length(prefix) + 1)
        gsub(/`/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        found = 1
        exit
      }
    }
    END {
      if (!found) print ""
    }
  ' "$RUN_LOG"
}

is_placeholder_value() {
  local value="$1"
  local lowered

  lowered="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  lowered="$(printf '%s' "$lowered" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

  case "$lowered" in
    ""|"tbd"|"todo"|"n/a"|"na"|"none"|"unknown"|"required"|"placeholder")
      return 0
      ;;
  esac

  if [[ "$lowered" == *"(required)"* ]]; then
    return 0
  fi

  if [[ "$lowered" == *"pass | fail | blocked"* || "$lowered" == *"pass|fail|blocked"* ]]; then
    return 0
  fi

  return 1
}

is_valid_utc_timestamp() {
  local value="$1"
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

failures=()
declare -a role_results=()
declare -a role_agents=()
declare -a role_scopes=()

for role in "${roles[@]}"; do
  if ! section_exists "$role"; then
    failures+=("$role:missing-section")
    continue
  fi

  agent_id="$(field_value "$role" "agent-id")"
  agent_id_lc="$(printf '%s' "$agent_id" | tr '[:upper:]' '[:lower:]')"
  role_lc="$(printf '%s' "$role" | tr '[:upper:]' '[:lower:]')"

  if is_placeholder_value "$agent_id"; then
    failures+=("$role:missing-agent-id")
  elif ! [[ "$agent_id" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]{2,}$ ]]; then
    failures+=("$role:invalid-agent-id($agent_id)")
  elif [[ "$agent_id_lc" == "$role_lc" ]]; then
    failures+=("$role:agent-id-cannot-match-role-name")
  else
    role_agents+=("$role:$agent_id")
  fi

  result_value="$(field_value "$role" "result")"
  result_value="$(printf '%s' "$result_value" | tr '[:lower:]' '[:upper:]')"

  case "$result_value" in
    PASS|FAIL|BLOCKED)
      ;;
    "")
      failures+=("$role:missing-result")
      ;;
    *)
      failures+=("$role:invalid-result($result_value)")
      ;;
  esac

  role_results+=("$role:$result_value")

  scope_value="$(field_value "$role" "scope")"
  if is_placeholder_value "$scope_value"; then
    failures+=("$role:missing-scope")
  fi
  role_scopes+=("$role:$scope_value")

  evidence_value="$(field_value "$role" "evidence")"
  if is_placeholder_value "$evidence_value"; then
    failures+=("$role:missing-evidence")
  fi
done

declare -a seen_agents=()
for role_agent in "${role_agents[@]-}"; do
  role="${role_agent%%:*}"
  agent_id="${role_agent#*:}"

  for seen in "${seen_agents[@]-}"; do
    seen_role="${seen%%:*}"
    seen_id="${seen#*:}"
    if [[ "$agent_id" == "$seen_id" ]]; then
      failures+=("multi-agent:duplicate-agent-id($agent_id:$seen_role,$role)")
    fi
  done

  seen_agents+=("$role:$agent_id")
done

reviewer_result=""
security_result=""
planner_result=""
implementer_result=""
planner_scope=""
orchestrator_scope=""
monitor_role="$(monitor_field_value "current-role")"
monitor_status="$(monitor_field_value "current-status")"
monitor_started_at="$(monitor_field_value "started-at-utc")"
monitor_last_progress_at="$(monitor_field_value "last-progress-at-utc")"
monitor_interrupt_after="$(monitor_field_value "interrupt-after-utc")"
monitor_last_progress="$(monitor_field_value "last-progress")"

if is_placeholder_value "$monitor_role"; then
  failures+=("dispatch-monitor:missing-current-role")
else
  case "$monitor_role" in
    orchestrator|planner|implementer|tester|gate-checker|reviewer|security)
      ;;
    *)
      failures+=("dispatch-monitor:invalid-current-role($monitor_role)")
      ;;
  esac
fi

if is_placeholder_value "$monitor_status"; then
  failures+=("dispatch-monitor:missing-current-status")
else
  monitor_status_uc="$(printf '%s' "$monitor_status" | tr '[:lower:]' '[:upper:]')"
  case "$monitor_status_uc" in
    QUEUED|RUNNING|AT_RISK|BLOCKED|DONE)
      ;;
    *)
      failures+=("dispatch-monitor:invalid-current-status($monitor_status)")
      ;;
  esac
fi

if is_placeholder_value "$monitor_started_at"; then
  failures+=("dispatch-monitor:missing-started-at-utc")
elif ! is_valid_utc_timestamp "$monitor_started_at"; then
  failures+=("dispatch-monitor:invalid-started-at-utc($monitor_started_at)")
fi

if is_placeholder_value "$monitor_last_progress_at"; then
  failures+=("dispatch-monitor:missing-last-progress-at-utc")
elif ! is_valid_utc_timestamp "$monitor_last_progress_at"; then
  failures+=("dispatch-monitor:invalid-last-progress-at-utc($monitor_last_progress_at)")
fi

if is_placeholder_value "$monitor_interrupt_after"; then
  failures+=("dispatch-monitor:missing-interrupt-after-utc")
elif ! is_valid_utc_timestamp "$monitor_interrupt_after"; then
  failures+=("dispatch-monitor:invalid-interrupt-after-utc($monitor_interrupt_after)")
fi

if is_placeholder_value "$monitor_last_progress"; then
  failures+=("dispatch-monitor:missing-last-progress")
fi

for item in "${role_results[@]}"; do
  role="${item%%:*}"
  result="${item#*:}"
  if [[ "$role" == "planner" ]]; then
    planner_result="$result"
  fi
  if [[ "$role" == "implementer" ]]; then
    implementer_result="$result"
  fi
  if [[ "$role" == "reviewer" ]]; then
    reviewer_result="$result"
  fi
  if [[ "$role" == "security" ]]; then
    security_result="$result"
  fi
done

for item in "${role_scopes[@]}"; do
  role="${item%%:*}"
  scope="${item#*:}"
  if [[ "$role" == "planner" ]]; then
    planner_scope="$scope"
  fi
  if [[ "$role" == "orchestrator" ]]; then
    orchestrator_scope="$scope"
  fi
done

if [[ -n "${monitor_started_at:-}" && -n "${monitor_last_progress_at:-}" ]] \
  && is_valid_utc_timestamp "$monitor_started_at" \
  && is_valid_utc_timestamp "$monitor_last_progress_at" \
  && [[ "$monitor_last_progress_at" < "$monitor_started_at" ]]; then
  failures+=("dispatch-monitor:last-progress-before-start")
fi

if [[ -n "${monitor_started_at:-}" && -n "${monitor_interrupt_after:-}" ]] \
  && is_valid_utc_timestamp "$monitor_started_at" \
  && is_valid_utc_timestamp "$monitor_interrupt_after" \
  && [[ "$monitor_interrupt_after" < "$monitor_started_at" ]]; then
  failures+=("dispatch-monitor:interrupt-before-start")
fi

if [[ "$reviewer_result" == "FAIL" && "$security_result" != "BLOCKED" ]]; then
  failures+=("state-machine:security-must-be-BLOCKED-when-reviewer-FAIL")
fi

if [[ "$reviewer_result" != "PASS" && "$security_result" == "PASS" ]]; then
  failures+=("state-machine:security-PASS-requires-reviewer-PASS")
fi

planner_scope_lc="$(printf '%s' "$planner_scope" | tr '[:upper:]' '[:lower:]')"
orchestrator_scope_lc="$(printf '%s' "$orchestrator_scope" | tr '[:upper:]' '[:lower:]')"

if [[ "$planner_scope_lc" != *"plan.md"* ]]; then
  failures+=("ownership:planner-scope-must-include-plan.md")
fi

if [[ "$orchestrator_scope_lc" == *"plan.md"* ]]; then
  failures+=("ownership:orchestrator-scope-must-exclude-plan.md")
fi

if [[ "$planner_result" != "PASS" && "$implementer_result" == "PASS" ]]; then
  failures+=("state-machine:implementer-PASS-requires-planner-PASS")
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] role-chain"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] role-chain"
