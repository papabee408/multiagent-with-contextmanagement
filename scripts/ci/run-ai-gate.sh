#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib.sh"
source "$SCRIPT_DIR/project-checks.sh"

CI_EVENT_NAME="${CI_EVENT_NAME:-local}"
CI_REF_NAME="${CI_REF_NAME:-}"
CI_HEAD_BRANCH="${CI_HEAD_BRANCH:-}"
CI_DIFF_BASE="${CI_DIFF_BASE:-}"
CI_DIFF_HEAD="${CI_DIFF_HEAD:-}"
CI_RUN_FULL_PROJECT_CHECKS="${CI_RUN_FULL_PROJECT_CHECKS:-0}"
CI_PR_BODY="${CI_PR_BODY:-}"
CI_TASK_ID="${CI_TASK_ID:-}"

is_truthy() {
  case "$(lower "${1:-}")" in
    1|true|yes)
      return 0
      ;;
  esac

  return 1
}

ci_changed_files() {
  committed_changed_files
}

changed_live_task_files() {
  ci_changed_files | awk '
    index($0, "docs/tasks/") == 1 &&
    $0 ~ /\.md$/ &&
    $0 != "docs/tasks/_template.md" &&
    $0 != "docs/tasks/README.md" { print }
  ' | sort -u
}

task_id_from_pr_metadata() {
  if [[ -z "$CI_PR_BODY" ]]; then
    printf '%s' ""
    return 0
  fi

  printf '%s\n' "$CI_PR_BODY" | extract_task_id_from_text
}

task_id_from_branch_input() {
  local branch_ref="${CI_HEAD_BRANCH:-$CI_REF_NAME}"
  task_id_from_branch_ref "$branch_ref"
}

detect_task_id_or_exit() {
  local explicit_task_id
  local metadata_task_id
  local metadata_task_id_status=0
  local branch_task_id
  local branch_task_id_status=0
  local task_files=()
  local task_file
  local task_id=""

  explicit_task_id="$(trim "$CI_TASK_ID")"
  metadata_task_id=""
  branch_task_id=""
  if branch_task_id="$(task_id_from_branch_input)"; then
    branch_task_id="$(trim "$branch_task_id")"
  else
    branch_task_id_status=$?
    if [[ "$branch_task_id_status" -eq 1 ]]; then
      branch_task_id=""
    else
      echo "[FAIL] ai-gate" >&2
      echo " - branch-derived task id is malformed" >&2
      exit 1
    fi
  fi
  while IFS= read -r task_file; do
    [[ -n "$task_file" ]] || continue
    task_files+=("$task_file")
  done < <(changed_live_task_files)

  if [[ -n "$explicit_task_id" ]]; then
    if task_exists "$explicit_task_id"; then
      printf '%s' "$explicit_task_id"
      return 0
    fi

    echo "[FAIL] ai-gate" >&2
    echo " - explicit Task-ID does not match a live task file" >&2
    echo " - explicit-task-id=$explicit_task_id" >&2
    exit 1
  fi

  if [[ -n "$CI_PR_BODY" ]]; then
    if metadata_task_id="$(task_id_from_pr_metadata)"; then
      metadata_task_id="$(trim "$metadata_task_id")"
    else
      metadata_task_id_status=$?
      if [[ "$metadata_task_id_status" -eq 1 ]]; then
        metadata_task_id=""
      else
        echo "[FAIL] ai-gate" >&2
        echo " - PR body Task-ID metadata is malformed or ambiguous" >&2
        exit 1
      fi
    fi

    if [[ -n "$metadata_task_id" ]]; then
      if task_exists "$metadata_task_id"; then
        printf '%s' "$metadata_task_id"
        return 0
      fi

      echo "[FAIL] ai-gate" >&2
      echo " - PR body Task-ID does not match a live task file" >&2
      echo " - pr-body-task-id=$metadata_task_id" >&2
      exit 1
    fi
  fi

  if [[ -n "$branch_task_id" ]]; then
    if task_exists "$branch_task_id"; then
      printf '%s' "$branch_task_id"
      return 0
    fi

    echo "[FAIL] ai-gate" >&2
    echo " - branch-derived task id does not match a live task file" >&2
    echo " - branch-task-id=$branch_task_id" >&2
    exit 1
  fi

  if [[ ${#task_files[@]} == 1 ]]; then
    task_id="${task_files[0]#docs/tasks/}"
    task_id="${task_id%.md}"
    if task_exists "$task_id"; then
      printf '%s' "$task_id"
      return 0
    fi
  fi

  echo "[FAIL] ai-gate" >&2
  echo " - could not resolve a task id from explicit Task-ID, PR body, branch name, or one changed task file" >&2
  [[ -n "$explicit_task_id" ]] && echo " - explicit-task-id=$explicit_task_id" >&2
  [[ -n "$metadata_task_id" ]] && echo " - pr-body-task-id=$metadata_task_id" >&2
  [[ -n "$branch_task_id" ]] && echo " - branch-task-id=$branch_task_id" >&2
  if [[ ${#task_files[@]} -gt 0 ]]; then
    printf ' - changed-task-file=%s\n' "${task_files[@]}" >&2
  fi
  exit 1
}

ensure_merge_ready_state() {
  local task_id="$1"
  local current_state

  current_state="$(task_state "$task_id")"
  if [[ "$current_state" != "done" ]]; then
    echo "[FAIL] ai-gate"
    echo " - task must be in state 'done' before CI passes"
    echo " - task=$task_id"
    echo " - current-state=$current_state"
    exit 1
  fi
}

run_task_verification_commands_ci() {
  local task_id="$1"
  local commands=()
  local command

  while IFS= read -r command; do
    [[ -n "$command" ]] || continue
    commands+=("$command")
  done < <(verification_commands_from_task "$task_id")

  if [[ ${#commands[@]} -eq 0 ]]; then
    echo "[FAIL] ai-gate"
    echo " - no verification commands declared for task: $task_id"
    exit 1
  fi

  for command in "${commands[@]}"; do
    run_ci_command_once "verification" "$command"
  done
}

main() {
  local task_id
  local risk_level

  task_id="$(detect_task_id_or_exit)"

  echo "[INFO] ai-gate task=$task_id event=$CI_EVENT_NAME ref=${CI_REF_NAME:-unknown}"

  CHECK_CONTEXT_MODE=ci bash "$ROOT_DIR/scripts/check-context.sh"
  bash "$ROOT_DIR/scripts/check-task.sh" "$task_id"
  reset_ci_command_history
  ensure_merge_ready_state "$task_id"
  CHECK_SCOPE_MODE=ci bash "$ROOT_DIR/scripts/check-scope.sh" "$task_id"
  run_task_verification_commands_ci "$task_id"

  run_project_checks_for_pr_fast "$task_id"

  risk_level="$(task_risk_level "$task_id")"
  if [[ "$risk_level" == "high-risk" ]]; then
    run_project_checks_for_high_risk "$task_id"
  fi

  if is_truthy "$CI_RUN_FULL_PROJECT_CHECKS"; then
    run_project_checks_for_main "$task_id"
  fi

  echo "[PASS] ai-gate"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
