#!/usr/bin/env bash

if [[ -z "${ROOT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/../_lib.sh"
fi

CI_COMMAND_HISTORY_FILE="${CI_COMMAND_HISTORY_FILE:-}"

normalize_ci_command() {
  trim "$1"
}

ensure_ci_command_history_file() {
  if [[ -n "$CI_COMMAND_HISTORY_FILE" && -f "$CI_COMMAND_HISTORY_FILE" ]]; then
    return 0
  fi

  CI_COMMAND_HISTORY_FILE="$(mktemp)"
}

reset_ci_command_history() {
  ensure_ci_command_history_file
  : > "$CI_COMMAND_HISTORY_FILE"
}

ci_command_previous_label() {
  local command="$1"

  ensure_ci_command_history_file
  awk -F '\t' -v command="$command" '$1 == command { print $2; exit }' "$CI_COMMAND_HISTORY_FILE"
}

record_ci_command_run() {
  local command="$1"
  local label="$2"

  ensure_ci_command_history_file
  printf '%s\t%s\n' "$command" "$label" >> "$CI_COMMAND_HISTORY_FILE"
}

run_ci_command_once() {
  local label="$1"
  local command="$2"
  local normalized_command
  local previous_label

  normalized_command="$(normalize_ci_command "$command")"
  if [[ -z "$normalized_command" ]]; then
    return 0
  fi

  previous_label="$(ci_command_previous_label "$normalized_command")"
  if [[ -n "$previous_label" ]]; then
    echo "[SKIP][$label] $command (already ran in $previous_label)"
    return 0
  fi

  echo "[RUN][$label] $command"
  bash -lc "cd \"$ROOT_DIR\" && $command"
  record_ci_command_run "$normalized_command" "$label"
}

run_ci_profile_section() {
  local task_id="$1"
  local section="$2"
  local label="$3"
  local profile_path
  local command
  local commands=()

  profile_path="$(ci_profile_file)"
  if [[ ! -f "$profile_path" ]]; then
    echo "[SKIP] no CI profile configured for task: $task_id"
    return 0
  fi

  while IFS= read -r command; do
    [[ -n "$command" ]] || continue
    commands+=("$command")
  done < <(ci_profile_commands "$section")

  if [[ ${#commands[@]} -eq 0 ]]; then
    echo "[SKIP] no $label commands configured for task: $task_id"
    return 0
  fi

  for command in "${commands[@]}"; do
    run_ci_command_once "$label" "$command"
  done
}

run_project_checks_for_pr_fast() {
  run_ci_profile_section "$1" "## PR Fast Checks" "pr-fast"
}

run_project_checks_for_high_risk() {
  run_ci_profile_section "$1" "## High-Risk Checks" "high-risk"
}

run_project_checks_for_main() {
  run_ci_profile_section "$1" "## Full Project Checks" "full-project"
}
