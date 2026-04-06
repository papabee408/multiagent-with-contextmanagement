#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="${1:-$(active_task_value)}"
CURRENT_FILE="$ROOT_DIR/docs/context/CURRENT.md"

mkdir -p "$ROOT_DIR/docs/context" "$CONTEXT_DIR"

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
1. \`docs/context/CURRENT.md\`
2. \`.context/active_task\`
3. \`docs/tasks/<task-id>.md\`
4. \`docs/context/PROJECT.md\`
5. \`docs/context/ARCHITECTURE.md\`
6. \`docs/context/CONVENTIONS.md\`
7. \`docs/context/DECISIONS.md\` only if needed

## Current State
- task-state: no active task
- risk-level: none
- review-profile: none
- approval: not-started
- current focus: choose or bootstrap a task
- next action: run \`bash scripts/bootstrap-task.sh <task-id>\`
- known risks: none

## Changed Files
- none

## Verification
- last-run-utc: none
- status: not-run
- fingerprint: none
- receipt-file: none

## Reviews
- scope-review: not-run
- scope-review-at-utc: none
- quality-review: not-run
- quality-review-at-utc: none
EOF
  echo "[OK] refreshed docs/context/CURRENT.md"
  exit 0
fi

TASK_FILE="$(task_file "$TASK_ID")"
STATE="$(section_key_value "$TASK_FILE" "## Status" "state")"
RISK_LEVEL="$(task_risk_level "$TASK_ID")"
REVIEW_PROFILE="$(task_review_profile "$TASK_ID")"
CURRENT_FOCUS="$(section_key_value "$TASK_FILE" "## Session Resume" "current focus")"
NEXT_ACTION="$(section_key_value "$TASK_FILE" "## Session Resume" "next action")"
KNOWN_RISKS="$(section_key_value "$TASK_FILE" "## Session Resume" "known risks")"
APPROVED_BY="$(section_key_value "$TASK_FILE" "## Approval" "approved-by")"
APPROVED_AT="$(section_key_value "$TASK_FILE" "## Approval" "approved-at-utc")"
RECEIPT_FILE_REL=".context/tasks/$TASK_ID/verification.receipt"
RECEIPT_FILE_ABS="$(verification_receipt_file "$TASK_ID")"
VERIFICATION_STATUS="$(receipt_value "$RECEIPT_FILE_ABS" "result")"
VERIFICATION_TIME="$(receipt_value "$RECEIPT_FILE_ABS" "executed_at_utc")"
VERIFICATION_FINGERPRINT="$(receipt_value "$RECEIPT_FILE_ABS" "fingerprint")"
SCOPE_REVIEW_FILE_ABS="$(scope_review_receipt_file "$TASK_ID")"
QUALITY_REVIEW_FILE_ABS="$(quality_review_receipt_file "$TASK_ID")"
INDEPENDENT_REVIEW_FILE_ABS="$(independent_review_receipt_file "$TASK_ID")"
SCOPE_REVIEW_STATUS="$(receipt_value "$SCOPE_REVIEW_FILE_ABS" "result")"
SCOPE_REVIEW_TIME="$(receipt_value "$SCOPE_REVIEW_FILE_ABS" "executed_at_utc")"
QUALITY_REVIEW_STATUS="$(receipt_value "$QUALITY_REVIEW_FILE_ABS" "result")"
QUALITY_REVIEW_TIME="$(receipt_value "$QUALITY_REVIEW_FILE_ABS" "executed_at_utc")"
INDEPENDENT_REVIEW_STATUS="$(receipt_value "$INDEPENDENT_REVIEW_FILE_ABS" "result")"
INDEPENDENT_REVIEW_TIME="$(receipt_value "$INDEPENDENT_REVIEW_FILE_ABS" "executed_at_utc")"

if [[ -z "$VERIFICATION_STATUS" ]]; then
  VERIFICATION_STATUS="not-run"
fi
if [[ -z "$VERIFICATION_TIME" ]]; then
  VERIFICATION_TIME="none"
fi
if [[ -z "$VERIFICATION_FINGERPRINT" ]]; then
  VERIFICATION_FINGERPRINT="none"
fi
if [[ -z "$SCOPE_REVIEW_STATUS" ]]; then
  SCOPE_REVIEW_STATUS="not-run"
fi
if [[ -z "$SCOPE_REVIEW_TIME" ]]; then
  SCOPE_REVIEW_TIME="none"
fi
if [[ -z "$QUALITY_REVIEW_STATUS" ]]; then
  QUALITY_REVIEW_STATUS="not-run"
fi
if [[ -z "$QUALITY_REVIEW_TIME" ]]; then
  QUALITY_REVIEW_TIME="none"
fi
if [[ -z "$INDEPENDENT_REVIEW_STATUS" ]]; then
  INDEPENDENT_REVIEW_STATUS="not-run"
fi
if [[ -z "$INDEPENDENT_REVIEW_TIME" ]]; then
  INDEPENDENT_REVIEW_TIME="none"
fi

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
1. \`docs/context/CURRENT.md\`
2. \`.context/active_task\`
3. \`docs/tasks/$TASK_ID.md\`
4. \`docs/context/PROJECT.md\`
5. \`docs/context/ARCHITECTURE.md\`
6. \`docs/context/CONVENTIONS.md\`
7. \`docs/context/DECISIONS.md\` only if the task or diff depends on prior decisions

## Current State
- task-state: $STATE
- risk-level: $RISK_LEVEL
- review-profile: $REVIEW_PROFILE
- approval: $APPROVAL_STATUS
- current focus: $CURRENT_FOCUS
- next action: $NEXT_ACTION
- known risks: $KNOWN_RISKS

## Changed Files
$(render_changed_files "$TASK_ID")

## Verification
- last-run-utc: $VERIFICATION_TIME
- status: $VERIFICATION_STATUS
- fingerprint: $VERIFICATION_FINGERPRINT
- receipt-file: $RECEIPT_FILE_REL

## Reviews
- scope-review: $SCOPE_REVIEW_STATUS
- scope-review-at-utc: $SCOPE_REVIEW_TIME
- quality-review: $QUALITY_REVIEW_STATUS
- quality-review-at-utc: $QUALITY_REVIEW_TIME
- independent-review: $INDEPENDENT_REVIEW_STATUS
- independent-review-at-utc: $INDEPENDENT_REVIEW_TIME
EOF

echo "[OK] refreshed docs/context/CURRENT.md"
