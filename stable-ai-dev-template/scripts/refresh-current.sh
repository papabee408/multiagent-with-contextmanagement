#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="${1:-}"
if [[ -z "$TASK_ID" && -f "$ACTIVE_TASK_FILE" ]]; then
  TASK_ID="$(tr -d ' \n\r\t' < "$ACTIVE_TASK_FILE")"
fi
CURRENT_FILE="$CURRENT_SNAPSHOT_FILE"

mkdir -p "$CONTEXT_DIR"

render_changed_files() {
  local task_id="$1"
  local printed=0

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    printf -- '- `%s`\n' "$relative_path"
    printed=1
  done < <(effective_changed_files "$task_id")

  if [[ "$printed" == "0" ]]; then
    echo "- none"
  fi
}

if [[ -z "$TASK_ID" || ! -f "$(task_file "$TASK_ID")" ]]; then
  cat > "$CURRENT_FILE" <<EOF
# Current Snapshot

- last-updated-utc: $(utc_now)
- active-task: none
- active-task-file: none

## Read This First
1. \`.context/current.md\`
2. \`.context/active_task\`
3. \`docs/tasks/<task-id>.md\`
4. \`docs/context/CURRENT.md\`
5. \`docs/context/PROJECT.md\`
6. \`docs/context/ARCHITECTURE.md\`
7. \`docs/context/CONVENTIONS.md\`
8. \`docs/context/CI_PROFILE.md\` only if needed
9. \`docs/context/DECISIONS.md\` only if needed

## Current State
- task-state: no active task
- risk-level: none
- approval: not-started
- current focus: choose or bootstrap a task
- next action: run \`bash scripts/bootstrap-task.sh <task-id>\`
- known risks: none

## Git / PR
- base-branch: none
- branch-strategy: none
- current-branch: none
- ahead-of-origin-base: none
- behind-origin-base: none
- pr-status: none
- pr-number: none
- pr-url: none
- latest-published-head-sha: none

## Effective Changed Files
- none

## Verification
- verification-status: not-run
- verification-at-utc: none

## Reviews
- scope-review-status: not-run
- scope-review-at-utc: none
- quality-review-status: not-run
- quality-review-at-utc: none
EOF
  echo "[OK] refreshed .context/current.md"
  exit 0
fi

TASK_FILE="$(task_file "$TASK_ID")"
STATE="$(task_state "$TASK_ID")"
RISK_LEVEL="$(task_risk_level "$TASK_ID")"
CURRENT_FOCUS="$(section_key_value "$TASK_FILE" "## Session Resume" "current focus")"
NEXT_ACTION="$(section_key_value "$TASK_FILE" "## Session Resume" "next action")"
KNOWN_RISKS="$(section_key_value "$TASK_FILE" "## Session Resume" "known risks")"
APPROVED_BY="$(section_key_value "$TASK_FILE" "## Approval" "approved-by")"
APPROVED_AT="$(section_key_value "$TASK_FILE" "## Approval" "approved-at-utc")"

BASE_BRANCH="$(base_branch_from_task "$TASK_ID")"
BRANCH_STRATEGY="$(branch_strategy_from_task "$TASK_ID")"
CURRENT_BRANCH="$(current_branch_name)"

AHEAD="none"
BEHIND="none"
if has_origin_remote && [[ -n "$BASE_BRANCH" ]]; then
  read -r BEHIND AHEAD < <(ahead_behind_against_origin_base "$BASE_BRANCH")
fi

PR_STATUS="$(pr_state_value "$TASK_ID" "pr_status")"
PR_NUMBER="$(pr_state_value "$TASK_ID" "pr_number")"
PR_URL="$(pr_state_value "$TASK_ID" "pr_url")"
PR_HEAD_SHA="$(pr_state_value "$TASK_ID" "head_sha")"
[[ -z "$PR_STATUS" ]] && PR_STATUS="none"
[[ -z "$PR_NUMBER" ]] && PR_NUMBER="none"
[[ -z "$PR_URL" ]] && PR_URL="none"
[[ -z "$PR_HEAD_SHA" ]] && PR_HEAD_SHA="none"

VERIFICATION_STATUS="$(section_key_value "$TASK_FILE" "## Verification Status" "verification-status")"
VERIFICATION_AT="$(section_key_value "$TASK_FILE" "## Verification Status" "verification-at-utc")"
SCOPE_STATUS="$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-status")"
SCOPE_AT="$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-at-utc")"
QUALITY_STATUS="$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-status")"
QUALITY_AT="$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-at-utc")"

[[ -z "$VERIFICATION_STATUS" ]] && VERIFICATION_STATUS="not-run"
[[ -z "$VERIFICATION_AT" ]] && VERIFICATION_AT="none"
[[ -z "$SCOPE_STATUS" ]] && SCOPE_STATUS="not-run"
[[ -z "$SCOPE_AT" ]] && SCOPE_AT="none"
[[ -z "$QUALITY_STATUS" ]] && QUALITY_STATUS="not-run"
[[ -z "$QUALITY_AT" ]] && QUALITY_AT="none"

APPROVAL_STATUS="pending"
if ! placeholder_like "$APPROVED_BY" && ! placeholder_like "$APPROVED_AT"; then
  APPROVAL_STATUS="approved by $APPROVED_BY at $APPROVED_AT"
fi

cat > "$CURRENT_FILE" <<EOF
# Current Snapshot

- last-updated-utc: $(utc_now)
- active-task: $TASK_ID
- active-task-file: docs/tasks/$TASK_ID.md

## Read This First
1. \`.context/current.md\`
2. \`.context/active_task\`
3. \`docs/tasks/$TASK_ID.md\`
4. \`docs/context/CURRENT.md\`
5. \`docs/context/PROJECT.md\`
6. \`docs/context/ARCHITECTURE.md\`
7. \`docs/context/CONVENTIONS.md\`
8. \`docs/context/CI_PROFILE.md\` only if needed
9. \`docs/context/DECISIONS.md\` only if needed

## Current State
- task-state: $STATE
- risk-level: $RISK_LEVEL
- approval: $APPROVAL_STATUS
- current focus: $CURRENT_FOCUS
- next action: $NEXT_ACTION
- known risks: $KNOWN_RISKS

## Git / PR
- base-branch: ${BASE_BRANCH:-none}
- branch-strategy: ${BRANCH_STRATEGY:-none}
- current-branch: ${CURRENT_BRANCH:-none}
- ahead-of-origin-base: $AHEAD
- behind-origin-base: $BEHIND
- pr-status: $PR_STATUS
- pr-number: $PR_NUMBER
- pr-url: $PR_URL
- latest-published-head-sha: $PR_HEAD_SHA

## Effective Changed Files
$(render_changed_files "$TASK_ID")

## Verification
- verification-status: $VERIFICATION_STATUS
- verification-at-utc: $VERIFICATION_AT

## Reviews
- scope-review-status: $SCOPE_STATUS
- scope-review-at-utc: $SCOPE_AT
- quality-review-status: $QUALITY_STATUS
- quality-review-at-utc: $QUALITY_AT
EOF

echo "[OK] refreshed .context/current.md"
