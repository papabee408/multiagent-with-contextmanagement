#!/usr/bin/env bash

if [[ -z "${ROOT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/../_lib.sh"
fi

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
    echo "[RUN][$label] $command"
    bash -lc "cd \"$ROOT_DIR\" && $command"
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
