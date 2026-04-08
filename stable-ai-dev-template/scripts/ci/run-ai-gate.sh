#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib.sh"
source "$SCRIPT_DIR/project-checks.sh"

CI_EVENT_NAME="${CI_EVENT_NAME:-local}"
CI_REF_NAME="${CI_REF_NAME:-}"
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
  if [[ -n "$CI_DIFF_BASE" && -n "$CI_DIFF_HEAD" ]]; then
    git -C "$ROOT_DIR" diff --name-only "$CI_DIFF_BASE...$CI_DIFF_HEAD" | sed '/^$/d' | sort -u
    return 0
  fi

  if git -C "$ROOT_DIR" rev-parse HEAD~1 >/dev/null 2>&1; then
    git -C "$ROOT_DIR" diff --name-only HEAD~1 HEAD | sed '/^$/d' | sort -u
    return 0
  fi

  git -C "$ROOT_DIR" ls-files | sed '/^$/d' | sort -u
}

ci_non_internal_changed_files() {
  local task_id="$1"
  local relative_path

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    if is_workflow_internal_file "$task_id" "$relative_path"; then
      continue
    fi
    printf '%s\n' "$relative_path"
  done < <(ci_changed_files)
}

ci_task_fingerprint() {
  local task_id="$1"
  local has_files=0
  local relative_path

  {
    echo "task-id=$task_id"
    echo "task-contract"
    task_contract_fingerprint_material "$task_id"
    echo "changed-files"
    while IFS= read -r relative_path; do
      [[ -n "$relative_path" ]] || continue
      has_files=1
      printf '%s\t%s\n' "$relative_path" "$(path_digest "$relative_path")"
    done < <(ci_non_internal_changed_files "$task_id")
    if [[ "$has_files" == "0" ]]; then
      echo "__empty__"
    fi
  } | sha256_stdin
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
    return 0
  fi

  printf '%s\n' "$CI_PR_BODY" | extract_task_id_from_text
}

detect_task_id_or_exit() {
  local metadata_task_id
  local task_files=()
  local task_file
  local task_id=""

  if [[ -n "$CI_TASK_ID" ]]; then
    printf '%s' "$CI_TASK_ID"
    return 0
  fi

  metadata_task_id="$(task_id_from_pr_metadata || true)"
  while IFS= read -r task_file; do
    [[ -n "$task_file" ]] || continue
    task_files+=("$task_file")
  done < <(changed_live_task_files)

  if [[ -n "$metadata_task_id" ]]; then
    if [[ ! -f "$(task_file "$metadata_task_id")" ]]; then
      echo "[FAIL] ai-gate"
      echo " - PR body Task-ID does not map to a task file: $metadata_task_id"
      exit 1
    fi

    if [[ ${#task_files[@]} -gt 0 ]]; then
      for task_file in "${task_files[@]}"; do
        if [[ "$task_file" != "docs/tasks/$metadata_task_id.md" ]]; then
          echo "[FAIL] ai-gate"
          echo " - PR body Task-ID does not match changed task file(s)"
          printf ' - %s\n' "${task_files[@]}"
          exit 1
        fi
      done
    fi

    printf '%s' "$metadata_task_id"
    return 0
  fi

  if [[ ${#task_files[@]} == 1 ]]; then
    task_id="${task_files[0]#docs/tasks/}"
    task_id="${task_id%.md}"
    printf '%s' "$task_id"
    return 0
  fi

  echo "[FAIL] ai-gate"
  if [[ ${#task_files[@]} == 0 ]]; then
    echo " - could not resolve a task id from PR body Task-ID or changed task files"
  else
    echo " - multiple changed task files and no clear Task-ID metadata"
    printf ' - %s\n' "${task_files[@]}"
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

check_ci_scope() {
  local task_id="$1"
  local allowed_tmp
  local violations=()
  local relative_path

  allowed_tmp="$(mktemp)"
  {
    target_files_from_task "$task_id"
    printf '%s\n' "docs/tasks/$task_id.md"
    printf '%s\n' "docs/context/CURRENT.md"
    printf '%s\n' "docs/context/DECISIONS.md"
  } | sort -u > "$allowed_tmp"

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    if is_workflow_internal_file "$task_id" "$relative_path"; then
      continue
    fi
    if grep -Fxq "$relative_path" "$allowed_tmp"; then
      continue
    fi
    violations+=("$relative_path")
  done < <(ci_changed_files)

  rm -f "$allowed_tmp"

  if [[ ${#violations[@]} -gt 0 ]]; then
    echo "[FAIL] ai-gate"
    echo " - CI scope check failed for task: $task_id"
    printf ' - %s\n' "${violations[@]}"
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
    echo "[RUN] $command"
    bash -lc "cd \"$ROOT_DIR\" && $command"
  done
}

check_summary_statuses_ci() {
  local task_id="$1"
  local risk_level
  local current_fingerprint
  local verification_status
  local verification_note
  local verification_at
  local verification_fingerprint
  local scope_status
  local scope_note
  local scope_at
  local scope_fingerprint
  local quality_status
  local quality_note
  local quality_at
  local quality_fingerprint
  local required_keys=()
  local key
  local value

  risk_level="$(task_risk_level "$task_id")"
  current_fingerprint="$(ci_task_fingerprint "$task_id")"

  verification_status="$(lower "$(section_key_value "$(task_file "$task_id")" "## Verification Status" "verification-status")")"
  verification_note="$(section_key_value "$(task_file "$task_id")" "## Verification Status" "verification-note")"
  verification_at="$(section_key_value "$(task_file "$task_id")" "## Verification Status" "verification-at-utc")"
  verification_fingerprint="$(section_key_value "$(task_file "$task_id")" "## Verification Status" "verification-fingerprint")"

  scope_status="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-status")")"
  scope_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-note")"
  scope_at="$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-at-utc")"
  scope_fingerprint="$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-fingerprint")"

  quality_status="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-status")")"
  quality_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-note")"
  quality_at="$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-at-utc")"
  quality_fingerprint="$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-fingerprint")"

  [[ "$verification_status" == "pass" ]] || {
    echo "[FAIL] ai-gate"
    echo " - verification-status must be pass"
    exit 1
  }
  [[ "$scope_status" == "pass" ]] || {
    echo "[FAIL] ai-gate"
    echo " - scope-review-status must be pass"
    exit 1
  }
  [[ "$quality_status" == "pass" ]] || {
    echo "[FAIL] ai-gate"
    echo " - quality-review-status must be pass"
    exit 1
  }

  if placeholder_like "$verification_note" || placeholder_like "$verification_at" || placeholder_like "$verification_fingerprint"; then
    echo "[FAIL] ai-gate"
    echo " - verification summary fields are incomplete"
    exit 1
  fi
  if placeholder_like "$scope_note" || placeholder_like "$scope_at" || placeholder_like "$scope_fingerprint"; then
    echo "[FAIL] ai-gate"
    echo " - scope review summary fields are incomplete"
    exit 1
  fi
  if placeholder_like "$quality_note" || placeholder_like "$quality_at" || placeholder_like "$quality_fingerprint"; then
    echo "[FAIL] ai-gate"
    echo " - quality review summary fields are incomplete"
    exit 1
  fi

  if [[ "$verification_fingerprint" != "$current_fingerprint" ]]; then
    echo "[FAIL] ai-gate"
    echo " - verification summary fingerprint is stale"
    exit 1
  fi
  if [[ "$scope_fingerprint" != "$current_fingerprint" ]]; then
    echo "[FAIL] ai-gate"
    echo " - scope review summary fingerprint is stale"
    exit 1
  fi
  if [[ "$quality_fingerprint" != "$current_fingerprint" ]]; then
    echo "[FAIL] ai-gate"
    echo " - quality review summary fingerprint is stale"
    exit 1
  fi

  case "$risk_level" in
    standard)
      required_keys=("reuse-review" "hardcoding-review" "tests-review" "request-scope-review")
      ;;
    high-risk)
      required_keys=("reuse-review" "hardcoding-review" "tests-review" "request-scope-review" "risk-controls-review")
      ;;
  esac

  for key in "${required_keys[@]}"; do
    value="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "$key")")"
    if [[ "$value" != "pass" ]]; then
      echo "[FAIL] ai-gate"
      echo " - review field '$key' must be pass"
      exit 1
    fi
  done
}

main() {
  local task_id
  local risk_level

  task_id="$(detect_task_id_or_exit)"

  mkdir -p "$CONTEXT_DIR"
  printf '%s\n' "$task_id" > "$ACTIVE_TASK_FILE"

  echo "[INFO] ai-gate task=$task_id event=$CI_EVENT_NAME ref=${CI_REF_NAME:-unknown}"

  bash "$ROOT_DIR/scripts/check-context.sh"
  bash "$ROOT_DIR/scripts/check-task.sh" "$task_id"
  ensure_merge_ready_state "$task_id"
  check_ci_scope "$task_id"
  check_summary_statuses_ci "$task_id"
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

main "$@"
