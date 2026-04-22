#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="${1:-}"
if [[ -z "$TASK_ID" ]]; then
  TASK_ID="$(branch_task_value)"
fi

render_changed_files() {
  local task_id="$1"
  local printed=0
  local relative_path

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    printf -- '- `%s`\n' "$relative_path"
    printed=1
  done < <(effective_changed_files "$task_id")

  if [[ "$printed" == "0" ]]; then
    echo "- none"
  fi
}

current_focus_for_task() {
  local task_id="$1"
  local state="$2"
  local verification_status="$3"
  local scope_status="$4"
  local quality_status="$5"
  local pr_status="$6"
  local task_branch_present="$7"
  local local_changes_present="$8"

  case "$state" in
    planning)
      printf '%s' "finish the task contract"
      ;;
    awaiting_approval)
      printf '%s' "task plan is waiting for approval"
      ;;
    approved)
      printf '%s' "task approved; implementation has not started"
      ;;
    in_progress)
      if [[ "$verification_status" == "fail" ]]; then
        printf '%s' "verification failed for the current diff"
      else
        printf '%s' "implement the approved plan inside the target files only"
      fi
      ;;
    review)
      if [[ "$quality_status" == "fail" ]]; then
        printf '%s' "quality review failed; address the recorded findings"
      elif [[ "$quality_status" == "pass" ]]; then
        printf '%s' "quality review recorded; task is ready for completion when freshness stays current"
      elif [[ "$scope_status" == "pass" ]]; then
        printf '%s' "scope review recorded; finish the remaining review work"
      else
        printf '%s' "review the current diff and record the required checks"
      fi
      ;;
    done)
      if [[ "$pr_status" == "open" || "$pr_status" == "draft" ]]; then
        printf '%s' "task completed; PR is published and waiting for landing"
      elif [[ "$pr_status" == "merged" ]]; then
        printf '%s' "task completed; PR is already merged"
      elif [[ "$pr_status" == "closed" ]]; then
        printf '%s' "task completed; PR is closed without merge"
      elif [[ "$pr_status" == "none" && "$task_branch_present" == "no" && "$local_changes_present" == "yes" ]]; then
        printf '%s' "task completed locally; publish has not started yet"
      elif [[ "$pr_status" == "none" && "$task_branch_present" == "no" ]]; then
        printf '%s' "task completed; publish branch is gone and PR status is unavailable locally"
      else
        printf '%s' "task completed; ready to land from the task branch"
      fi
      ;;
    superseded)
      printf '%s' "task superseded; continue in the replacement task"
      ;;
    *)
      printf '%s' "inspect the task contract"
      ;;
  esac
}

next_action_for_task() {
  local task_id="$1"
  local state="$2"
  local verification_status="$3"
  local scope_status="$4"
  local quality_status="$5"
  local pr_status="$6"
  local branch_strategy="$7"
  local task_branch_present="$8"
  local local_changes_present="$9"
  local follow_up

  follow_up="$(section_key_value "$(task_file "$task_id")" "## Completion" "follow-up")"

  case "$state" in
    planning)
      printf 'finish docs/tasks/%s.md and run `bash scripts/submit-task-plan.sh %s`' "$task_id" "$task_id"
      ;;
    awaiting_approval)
      printf '%s' "wait for approval or revise the task plan"
      ;;
    approved)
      printf 'run `bash scripts/start-task.sh %s`' "$task_id"
      ;;
    in_progress)
      if [[ "$verification_status" == "fail" ]]; then
        printf 'inspect `.context/tasks/%s/verification.log`, fix the failing command, and rerun `bash scripts/run-task-checks.sh %s`' "$task_id" "$task_id"
      elif [[ "$branch_strategy" == "publish-late" ]]; then
        printf 'edit approved files, then run `bash scripts/run-task-checks.sh %s`; create `task/%s` before the first commit' "$task_id" "$task_id"
      else
        printf 'edit approved files, then run `bash scripts/run-task-checks.sh %s` on `%s`' "$task_id" "$(task_branch_name "$task_id")"
      fi
      ;;
    review)
      if [[ "$quality_status" == "fail" ]]; then
        printf 'fix the review findings, rerun `bash scripts/run-task-checks.sh %s`, then rerun `bash scripts/review-quality.sh %s --summary "<quality note>" --architecture pass ...`' "$task_id" "$task_id"
      elif [[ "$scope_status" != "pass" ]]; then
        printf 'run `bash scripts/review-scope.sh %s --summary "<scope note>"`' "$task_id"
      elif [[ "$quality_status" != "pass" ]]; then
        printf 'run `bash scripts/review-quality.sh %s --summary "<quality note>" --architecture pass ...`' "$task_id"
      else
        printf 'run `bash scripts/complete-task.sh %s "<summary>" "<follow-up>"`' "$task_id"
      fi
      ;;
    done)
      if [[ "$pr_status" == "open" || "$pr_status" == "draft" ]]; then
        printf 'run `bash scripts/land-task.sh %s` after the published PR is ready to merge' "$task_id"
      elif [[ "$pr_status" == "merged" ]]; then
        printf '%s' "confirm local base is synced, then continue with the next task"
      elif [[ "$pr_status" == "closed" ]]; then
        printf '%s' "inspect why the PR was closed and decide whether to republish or supersede the task"
      elif [[ "$pr_status" == "none" && "$task_branch_present" == "no" && "$local_changes_present" == "yes" ]]; then
        if ! placeholder_like "$follow_up"; then
          printf '%s' "$follow_up"
        else
          printf 'create `%s`, commit the approved files, and run `bash scripts/open-task-pr.sh %s`' "$(task_branch_name "$task_id")" "$task_id"
        fi
      elif [[ "$pr_status" == "none" && "$task_branch_present" == "no" ]]; then
        printf '%s' "inspect remote PR history if needed, otherwise continue with the next task"
      else
        printf 'run `bash scripts/land-task.sh %s`' "$task_id"
      fi
      ;;
    superseded)
      if ! placeholder_like "$follow_up"; then
        printf '%s' "$follow_up"
      else
        printf '%s' "open the replacement task and continue there"
      fi
      ;;
    *)
      printf '%s' "inspect the task contract"
      ;;
  esac
}

known_risks_for_task() {
  local task_id="$1"
  local state="$2"
  local risk_level="$3"
  local sensitive_areas
  local extra_checks
  local follow_up

  sensitive_areas="$(section_key_value "$(task_file "$task_id")" "## Risk Controls" "sensitive areas touched")"
  extra_checks="$(section_key_value "$(task_file "$task_id")" "## Risk Controls" "extra checks before merge")"
  follow_up="$(section_key_value "$(task_file "$task_id")" "## Completion" "follow-up")"

  if [[ "$state" == "superseded" ]]; then
    if ! placeholder_like "$follow_up"; then
      printf '%s' "do not split work across the old task and its replacement"
    else
      printf '%s' "none"
    fi
    return 0
  fi

  if [[ "$risk_level" == "high-risk" ]]; then
    printf 'sensitive areas: %s; extra checks: %s' "${sensitive_areas:-none}" "${extra_checks:-none}"
    return 0
  fi

  if ! placeholder_like "$sensitive_areas" && [[ "$(lower "$sensitive_areas")" != "none" ]]; then
    printf 'sensitive areas: %s' "$sensitive_areas"
    return 0
  fi

  if ! placeholder_like "$extra_checks" && [[ "$(lower "$extra_checks")" != "none" ]]; then
    printf 'extra checks: %s' "$extra_checks"
    return 0
  fi

  printf '%s' "none"
}

task_branch_presence() {
  local branch_name="$1"

  if git -C "$ROOT_DIR" show-ref --verify --quiet "refs/heads/$branch_name"; then
    printf '%s' "yes"
    return 0
  fi

  if git -C "$ROOT_DIR" show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
    printf '%s' "yes"
    return 0
  fi

  printf '%s' "no"
}

task_has_local_changes() {
  local task_id="$1"
  local relative_path=""

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    if is_workflow_internal_file "$task_id" "$relative_path" || path_allowed_by_task "$task_id" "$relative_path"; then
      printf '%s' "yes"
      return 0
    fi
  done < <(
    {
      git -C "$ROOT_DIR" diff --name-only --cached 2>/dev/null || true
      git -C "$ROOT_DIR" diff --name-only 2>/dev/null || true
      git -C "$ROOT_DIR" ls-files --others --exclude-standard 2>/dev/null || true
    } | sed '/^$/d' | sort -u
  )

  printf '%s' "no"
}

if [[ -z "$TASK_ID" || ! -f "$(task_file "$TASK_ID")" ]]; then
  cat <<EOF
# Task Status

- active-task: none
- task-file: none
- task-state: no active task
- risk-level: none
- current-focus: choose or bootstrap a task
- next-action: run \`bash scripts/bootstrap-task.sh <task-id>\` from a clean worktree
- known-risks: none
- verification-log: none
- pr-status: none
- pr-number: none
- pr-url: none

## Changed Files
- none
EOF
  exit 0
fi

TASK_FILE="$(task_file "$TASK_ID")"
STATE="$(task_state "$TASK_ID")"
RISK_LEVEL="$(task_risk_level "$TASK_ID")"
BASE_BRANCH="$(base_branch_from_task "$TASK_ID")"
BRANCH_STRATEGY="$(branch_strategy_from_task "$TASK_ID")"
TASK_BRANCH="$(task_branch_name "$TASK_ID")"
TASK_BRANCH_PRESENT="$(task_branch_presence "$TASK_BRANCH")"
LOCAL_CHANGES_PRESENT="$(task_has_local_changes "$TASK_ID")"
CURRENT_BRANCH="$(current_branch_name 2>/dev/null || true)"
[[ -z "$CURRENT_BRANCH" ]] && CURRENT_BRANCH="none"

VERIFICATION_STATUS="$(lower "$(section_key_value "$TASK_FILE" "## Verification Status" "verification-status")")"
SCOPE_STATUS="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-status")")"
QUALITY_STATUS="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-status")")"
[[ -z "$VERIFICATION_STATUS" ]] && VERIFICATION_STATUS="not-run"
[[ -z "$SCOPE_STATUS" ]] && SCOPE_STATUS="not-run"
[[ -z "$QUALITY_STATUS" ]] && QUALITY_STATUS="not-run"

PR_SNAPSHOT="$(resolve_pr_snapshot_for_task "$TASK_ID" "$CURRENT_BRANCH")"
PR_STATUS="$(printf '%s\n' "$PR_SNAPSHOT" | sed -n '1p')"
PR_NUMBER="$(printf '%s\n' "$PR_SNAPSHOT" | sed -n '2p')"
PR_URL="$(printf '%s\n' "$PR_SNAPSHOT" | sed -n '3p')"
[[ -z "$PR_STATUS" ]] && PR_STATUS="none"
[[ -z "$PR_NUMBER" ]] && PR_NUMBER="none"
[[ -z "$PR_URL" ]] && PR_URL="none"

CURRENT_FOCUS="$(current_focus_for_task "$TASK_ID" "$STATE" "$VERIFICATION_STATUS" "$SCOPE_STATUS" "$QUALITY_STATUS" "$PR_STATUS" "$TASK_BRANCH_PRESENT" "$LOCAL_CHANGES_PRESENT")"
NEXT_ACTION="$(next_action_for_task "$TASK_ID" "$STATE" "$VERIFICATION_STATUS" "$SCOPE_STATUS" "$QUALITY_STATUS" "$PR_STATUS" "$BRANCH_STRATEGY" "$TASK_BRANCH_PRESENT" "$LOCAL_CHANGES_PRESENT")"
KNOWN_RISKS="$(known_risks_for_task "$TASK_ID" "$STATE" "$RISK_LEVEL")"

VERIFICATION_LOG="none"
if [[ "$VERIFICATION_STATUS" != "pass" ]]; then
  VERIFICATION_LOG=".context/tasks/$TASK_ID/verification.log"
fi

cat <<EOF
# Task Status

- active-task: $TASK_ID
- task-file: docs/tasks/$TASK_ID.md
- task-state: $STATE
- risk-level: $RISK_LEVEL
- base-branch: ${BASE_BRANCH:-none}
- branch-strategy: ${BRANCH_STRATEGY:-none}
- current-branch: ${CURRENT_BRANCH:-none}
- current-focus: $CURRENT_FOCUS
- next-action: $NEXT_ACTION
- known-risks: $KNOWN_RISKS
- verification-status: $VERIFICATION_STATUS
- verification-log: $VERIFICATION_LOG
- pr-status: ${PR_STATUS:-none}
- pr-number: ${PR_NUMBER:-none}
- pr-url: ${PR_URL:-none}

## Changed Files
$(render_changed_files "$TASK_ID")
EOF
