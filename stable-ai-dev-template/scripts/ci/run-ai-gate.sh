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

detect_task_id_or_exit() {
  local explicit_task_id
  local current_active_task
  local current_snapshot_task
  local task_file
  local detected_task_id
  local task_files=()
  local candidate_task_id

  explicit_task_id="${CI_TASK_ID:-}"
  if [[ -n "$explicit_task_id" ]]; then
    printf '%s' "$explicit_task_id"
    return 0
  fi

  while IFS= read -r task_file; do
    [[ -n "$task_file" ]] || continue
    task_files+=("$task_file")
  done < <(ci_changed_files | awk '
    index($0, "docs/tasks/") == 1 && $0 ~ /\.md$/ && $0 != "docs/tasks/_template.md" && $0 != "docs/tasks/README.md" { print }
  ')

  if [[ ${#task_files[@]} == 1 ]]; then
    detected_task_id="${task_files[0]#docs/tasks/}"
    detected_task_id="${detected_task_id%.md}"
    printf '%s' "$detected_task_id"
    return 0
  fi

  current_active_task="$(active_task_value)"
  current_snapshot_task="$(current_snapshot_active_task_value)"

  for candidate_task_id in "$current_active_task" "$current_snapshot_task"; do
    [[ -n "$candidate_task_id" ]] || continue
    [[ -f "$(task_file "$candidate_task_id")" ]] || continue

    if [[ ${#task_files[@]} == 0 ]]; then
      printf '%s' "$candidate_task_id"
      return 0
    fi

    for task_file in "${task_files[@]}"; do
      if [[ "$task_file" == "docs/tasks/$candidate_task_id.md" ]]; then
        printf '%s' "$candidate_task_id"
        return 0
      fi
    done
  done

  echo "[FAIL] ai-gate"
  if [[ ${#task_files[@]} == 0 ]]; then
    echo " - could not detect a task id from changed files"
  else
    echo " - expected exactly one changed task file, found ${#task_files[@]}"
    printf ' - %s\n' "${task_files[@]}"
  fi
  echo " - set CI_TASK_ID if the task cannot be inferred automatically"
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

  if [[ ${#violations[@]} -gt 0 ]]; then
    rm -f "$allowed_tmp"
    echo "[FAIL] ai-gate"
    echo " - CI scope check failed for task: $task_id"
    printf ' - %s\n' "${violations[@]}"
    exit 1
  fi

  rm -f "$allowed_tmp"
}

check_tracked_review_receipts_ci() {
  local task_id="$1"
  local risk_level
  local current_fingerprint
  local scope_tracked_receipt
  local quality_tracked_receipt
  local independent_tracked_receipt
  local receipt_result
  local receipt_fingerprint
  local receipt_summary
  local receipt_reviewer
  local task_scope_note
  local task_quality_note
  local task_independent_note
  local task_independent_reviewer
  local key
  local task_value
  local receipt_key
  local receipt_value_current

  risk_level="$(task_risk_level "$task_id")"
  current_fingerprint="$(ci_task_fingerprint "$task_id")"
  scope_tracked_receipt="$(tracked_scope_review_receipt_file "$task_id")"
  quality_tracked_receipt="$(tracked_quality_review_receipt_file "$task_id")"
  independent_tracked_receipt="$(tracked_independent_review_receipt_file "$task_id")"
  task_scope_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-note")"
  task_quality_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-note")"
  task_independent_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "independent-review-note")"
  task_independent_reviewer="$(section_key_value "$(task_file "$task_id")" "## Review Status" "independent-reviewer")"

  for tracked_receipt in "$scope_tracked_receipt" "$quality_tracked_receipt"; do
    if [[ ! -f "$tracked_receipt" ]]; then
      echo "[FAIL] ai-gate"
      echo " - missing tracked review receipt for task: $task_id"
      echo " - receipt=${tracked_receipt#$ROOT_DIR/}"
      exit 1
    fi
  done

  receipt_result="$(receipt_value "$scope_tracked_receipt" "result")"
  receipt_fingerprint="$(receipt_value "$scope_tracked_receipt" "fingerprint")"
  receipt_summary="$(receipt_value "$scope_tracked_receipt" "summary")"
  if [[ "$receipt_result" != "PASS" || "$receipt_fingerprint" != "$current_fingerprint" || "$receipt_summary" != "$task_scope_note" ]]; then
    echo "[FAIL] ai-gate"
    echo " - tracked scope review receipt is stale or mismatched for task: $task_id"
    exit 1
  fi

  receipt_result="$(receipt_value "$quality_tracked_receipt" "result")"
  receipt_fingerprint="$(receipt_value "$quality_tracked_receipt" "fingerprint")"
  receipt_summary="$(receipt_value "$quality_tracked_receipt" "summary")"
  if [[ "$receipt_result" != "PASS" || "$receipt_fingerprint" != "$current_fingerprint" || "$receipt_summary" != "$task_quality_note" ]]; then
    echo "[FAIL] ai-gate"
    echo " - tracked quality review receipt is stale or mismatched for task: $task_id"
    exit 1
  fi

  for key in reuse hardcoding tests request_scope risk_controls; do
    case "$key" in
      request_scope)
        task_value="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "request-scope-review")")"
        ;;
      risk_controls)
        task_value="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "risk-controls-review")")"
        ;;
      *)
        task_value="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "$key-review")")"
        ;;
    esac
    receipt_value_current="$(lower "$(receipt_value "$quality_tracked_receipt" "$key")")"
    if [[ -n "$receipt_value_current" && "$receipt_value_current" != "$task_value" ]]; then
      echo "[FAIL] ai-gate"
      echo " - tracked quality review receipt does not match task review fields for task: $task_id"
      exit 1
    fi
  done

  case "$risk_level" in
    standard|high-risk)
      if [[ ! -f "$independent_tracked_receipt" ]]; then
        echo "[FAIL] ai-gate"
        echo " - missing tracked independent review receipt for task: $task_id"
        exit 1
      fi
      receipt_result="$(receipt_value "$independent_tracked_receipt" "result")"
      receipt_fingerprint="$(receipt_value "$independent_tracked_receipt" "fingerprint")"
      receipt_summary="$(receipt_value "$independent_tracked_receipt" "summary")"
      receipt_reviewer="$(receipt_value "$independent_tracked_receipt" "reviewer")"
      if [[ "$receipt_result" != "PASS" || "$receipt_fingerprint" != "$current_fingerprint" || "$receipt_summary" != "$task_independent_note" || "$receipt_reviewer" != "$task_independent_reviewer" ]]; then
        echo "[FAIL] ai-gate"
        echo " - tracked independent review receipt is stale or mismatched for task: $task_id"
        exit 1
      fi
      ;;
  esac
}

run_task_verification_commands_ci() {
  local task_id="$1"
  local commands=()
  local command

  while IFS= read -r command; do
    [[ -n "$command" ]] || continue
    commands+=("$command")
  done < <(verification_commands_from_task "$task_id")

  if [[ ${#commands[@]} == 0 ]]; then
    echo "[FAIL] ai-gate"
    echo " - no verification commands declared for task: $task_id"
    exit 1
  fi

  for command in "${commands[@]}"; do
    echo "[RUN] $command"
    bash -lc "cd \"$ROOT_DIR\" && $command"
  done
}

check_review_status_ci() {
  local task_id="$1"
  local risk_level
  local scope_status
  local quality_status
  local independent_status
  local scope_note
  local quality_note
  local scope_fingerprint
  local quality_fingerprint
  local independent_note
  local independent_reviewer
  local independent_fingerprint
  local independent_proof
  local expected_independent_proof
  local current_fingerprint
  local value
  local required_keys=()

  risk_level="$(task_risk_level "$task_id")"
  scope_status="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-status")")"
  quality_status="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-status")")"
  independent_status="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "independent-review-status")")"
  scope_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-note")"
  quality_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-note")"
  scope_fingerprint="$(section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-fingerprint")"
  quality_fingerprint="$(section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-fingerprint")"
  independent_note="$(section_key_value "$(task_file "$task_id")" "## Review Status" "independent-review-note")"
  independent_reviewer="$(section_key_value "$(task_file "$task_id")" "## Review Status" "independent-reviewer")"
  independent_fingerprint="$(section_key_value "$(task_file "$task_id")" "## Review Status" "independent-review-fingerprint")"
  independent_proof="$(section_key_value "$(task_file "$task_id")" "## Review Status" "independent-review-proof")"
  current_fingerprint="$(ci_task_fingerprint "$task_id")"

  if [[ "$scope_status" != "pass" ]]; then
    echo "[FAIL] ai-gate"
    echo " - scope review must be PASS for task: $task_id"
    exit 1
  fi
  if [[ "$quality_status" != "pass" ]]; then
    echo "[FAIL] ai-gate"
    echo " - quality review must be PASS for task: $task_id"
    exit 1
  fi
  if placeholder_like "$scope_note" || placeholder_like "$quality_note"; then
    echo "[FAIL] ai-gate"
    echo " - review notes must be recorded for task: $task_id"
    exit 1
  fi
  if [[ "$scope_fingerprint" != "$current_fingerprint" || "$quality_fingerprint" != "$current_fingerprint" ]]; then
    echo "[FAIL] ai-gate"
    echo " - review fingerprints are stale for task: $task_id"
    exit 1
  fi

  case "$risk_level" in
    trivial)
      return 0
      ;;
    standard)
      if [[ "$independent_status" != "pass" ]]; then
        echo "[FAIL] ai-gate"
        echo " - independent review must be PASS for task: $task_id"
        exit 1
      fi
      if placeholder_like "$independent_note" || placeholder_like "$independent_reviewer"; then
        echo "[FAIL] ai-gate"
        echo " - independent review note and reviewer must be recorded for task: $task_id"
        exit 1
      fi
      if [[ "$independent_fingerprint" != "$current_fingerprint" ]]; then
        echo "[FAIL] ai-gate"
        echo " - independent review fingerprint is stale for task: $task_id"
        exit 1
      fi
      expected_independent_proof="$(independent_review_proof_for_fingerprint "$task_id" "$current_fingerprint" "$independent_reviewer" "$independent_note")"
      if [[ "$independent_proof" != "$expected_independent_proof" ]]; then
        echo "[FAIL] ai-gate"
        echo " - independent review proof is invalid for task: $task_id"
        exit 1
      fi
      required_keys=("reuse-review" "hardcoding-review" "tests-review" "request-scope-review")
      ;;
    high-risk)
      if [[ "$independent_status" != "pass" ]]; then
        echo "[FAIL] ai-gate"
        echo " - independent review must be PASS for task: $task_id"
        exit 1
      fi
      if placeholder_like "$independent_note" || placeholder_like "$independent_reviewer"; then
        echo "[FAIL] ai-gate"
        echo " - independent review note and reviewer must be recorded for task: $task_id"
        exit 1
      fi
      if [[ "$independent_fingerprint" != "$current_fingerprint" ]]; then
        echo "[FAIL] ai-gate"
        echo " - independent review fingerprint is stale for task: $task_id"
        exit 1
      fi
      expected_independent_proof="$(independent_review_proof_for_fingerprint "$task_id" "$current_fingerprint" "$independent_reviewer" "$independent_note")"
      if [[ "$independent_proof" != "$expected_independent_proof" ]]; then
        echo "[FAIL] ai-gate"
        echo " - independent review proof is invalid for task: $task_id"
        exit 1
      fi
      required_keys=("reuse-review" "hardcoding-review" "tests-review" "request-scope-review" "risk-controls-review")
      ;;
    *)
      echo "[FAIL] ai-gate"
      echo " - unsupported risk level for task: $task_id"
      exit 1
      ;;
  esac

  for key in "${required_keys[@]}"; do
    value="$(lower "$(section_key_value "$(task_file "$task_id")" "## Review Status" "$key")")"
    if [[ "$value" != "pass" ]]; then
      echo "[FAIL] ai-gate"
      echo " - review field '$key' must be PASS for task: $task_id"
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
  run_task_verification_commands_ci "$task_id"
  check_tracked_review_receipts_ci "$task_id"
  check_review_status_ci "$task_id"

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
