#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
TASK_FILE="$(task_file "$TASK_ID")"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[FAIL] task: missing file docs/tasks/$TASK_ID.md"
  exit 1
fi

failures=()

state="$(section_key_value "$TASK_FILE" "## Status" "state")"
case "$state" in
  planning|awaiting_approval|approved|in_progress|review|done|superseded)
    ;;
  *)
    failures+=("invalid-state($state)")
    ;;
esac

risk_level="$(task_risk_level "$TASK_ID")"
case "$risk_level" in
  trivial|standard|high-risk)
    ;;
  *)
    failures+=("invalid-risk-level($risk_level)")
    ;;
esac

updated_at="$(section_key_value "$TASK_FILE" "## Status" "updated-at-utc")"
if placeholder_like "$updated_at"; then
  failures+=("missing-updated-at-utc")
fi

approval_by="$(section_key_value "$TASK_FILE" "## Approval" "approved-by")"
approval_at="$(section_key_value "$TASK_FILE" "## Approval" "approved-at-utc")"
approval_note="$(section_key_value "$TASK_FILE" "## Approval" "approval-note")"
case "$state" in
  approved|in_progress|review|done)
    if placeholder_like "$approval_by"; then
      failures+=("missing-approved-by")
    fi
    if placeholder_like "$approval_at"; then
      failures+=("missing-approved-at-utc")
    fi
    if placeholder_like "$approval_note"; then
      failures+=("missing-approval-note")
    fi
    ;;
esac

clusters="$(section_key_value "$TASK_FILE" "## Intake" "user-visible-change-clusters")"
split_decision="$(section_key_value "$TASK_FILE" "## Intake" "split-decision")"
split_rationale="$(section_key_value "$TASK_FILE" "## Intake" "split-rationale")"
bundle_override="$(lower "$(section_key_value "$TASK_FILE" "## Intake" "bundle-override-approved")")"
if [[ ! "$clusters" =~ ^[1-9][0-9]*$ ]]; then
  failures+=("invalid-user-visible-change-clusters($clusters)")
fi
case "$split_decision" in
  single-task|user-bundled)
    ;;
  *)
    failures+=("invalid-split-decision($split_decision)")
    ;;
esac
if placeholder_like "$split_rationale"; then
  failures+=("missing-split-rationale")
fi
case "$bundle_override" in
  yes|no)
    ;;
  *)
    failures+=("invalid-bundle-override-approved($bundle_override)")
    ;;
esac

if [[ "$clusters" =~ ^[1-9][0-9]*$ && "$clusters" -gt 1 ]]; then
  if [[ "$split_decision" != "user-bundled" ]]; then
    failures+=("multi-cluster-requires-user-bundled")
  fi
  if [[ "$bundle_override" != "yes" ]]; then
    failures+=("multi-cluster-requires-bundle-override-approved")
  fi
  if [[ "$risk_level" == "trivial" ]]; then
    failures+=("multi-cluster-cannot-be-trivial")
  fi
fi

goal="$(section_bullet_values "$TASK_FILE" "## Goal" | head -n 1)"
if placeholder_like "$goal"; then
  failures+=("missing-goal")
fi

non_goal="$(section_bullet_values "$TASK_FILE" "## Non-goals" | head -n 1)"
if placeholder_like "$non_goal"; then
  failures+=("missing-non-goals")
fi

req_count=0
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  req_count=$((req_count + 1))
  if placeholder_like "${line#*: }"; then
    failures+=("placeholder-requirement($line)")
  fi
done < <(section_bullet_values "$TASK_FILE" "## Requirements")
if [[ "$req_count" == "0" ]]; then
  failures+=("missing-requirements")
fi

plan_count=0
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  plan_count=$((plan_count + 1))
  if placeholder_like "${line#*: }"; then
    failures+=("placeholder-implementation-plan($line)")
  fi
done < <(section_bullet_values "$TASK_FILE" "## Implementation Plan")
if [[ "$plan_count" == "0" ]]; then
  failures+=("missing-implementation-plan")
fi

target_count=0
declare -a seen_targets=()
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  target_count=$((target_count + 1))
  rule="$path"
  normalized_rule="$rule"

  if [[ "$rule" == delete-only:* ]]; then
    normalized_rule="${rule#delete-only:}"
    if [[ -z "$normalized_rule" ]]; then
      failures+=("invalid-delete-only-target($rule)")
      continue
    fi
  fi

  if [[ "$normalized_rule" == /* ]]; then
    failures+=("absolute-target-file($rule)")
  fi
  if [[ "$rule" != delete-only:* && "$rule" != */ ]] && is_workflow_internal_file "$TASK_ID" "$rule"; then
    failures+=("workflow-internal-target-file($rule)")
  fi
  for seen in "${seen_targets[@]-}"; do
    if [[ "$seen" == "$rule" ]]; then
      failures+=("duplicate-target-file($rule)")
    fi
  done
  seen_targets+=("$rule")
done < <(target_files_from_task "$TASK_ID")
if [[ "$target_count" == "0" ]]; then
  failures+=("missing-target-files")
fi

out_of_scope="$(section_bullet_values "$TASK_FILE" "## Out of Scope" | head -n 1)"
if placeholder_like "$out_of_scope"; then
  failures+=("missing-out-of-scope")
fi

for key in "unrelated changes allowed" "incidental refactors allowed"; do
  value="$(lower "$(section_key_value "$TASK_FILE" "## Scope Guardrails" "$key")")"
  case "$value" in
    yes|no)
      ;;
    *)
      failures+=("invalid-$key($value)")
      ;;
  esac
done

for key in "existing abstractions to reuse" "config/constants to centralize" "side effects to avoid"; do
  value="$(section_key_value "$TASK_FILE" "## Reuse And Constraints" "$key")"
  if placeholder_like "$value"; then
    failures+=("missing-$key")
  fi
done

sensitive_areas="$(section_key_value "$TASK_FILE" "## Risk Controls" "sensitive areas touched")"
extra_checks="$(section_key_value "$TASK_FILE" "## Risk Controls" "extra checks before merge")"
if placeholder_like "$sensitive_areas"; then
  failures+=("missing-sensitive-areas-touched")
fi
if placeholder_like "$extra_checks"; then
  failures+=("missing-extra-checks-before-merge")
fi
if [[ "$risk_level" == "high-risk" ]]; then
  if [[ "$(lower "$sensitive_areas")" == "none" ]]; then
    failures+=("high-risk-sensitive-areas-required")
  fi
  if [[ "$(lower "$extra_checks")" == "none" ]]; then
    failures+=("high-risk-extra-checks-required")
  fi
fi

acceptance="$(section_bullet_values "$TASK_FILE" "## Acceptance" | head -n 1)"
if placeholder_like "$acceptance"; then
  failures+=("missing-acceptance")
fi

verification_count=0
while IFS= read -r command; do
  [[ -n "$command" ]] || continue
  verification_count=$((verification_count + 1))
done < <(verification_commands_from_task "$TASK_ID")
if [[ "$verification_count" == "0" ]]; then
  failures+=("missing-verification-commands")
fi

base_branch="$(base_branch_from_task "$TASK_ID")"
branch_strategy="$(branch_strategy_from_task "$TASK_ID")"
if placeholder_like "$base_branch"; then
  failures+=("missing-base-branch")
fi
case "$branch_strategy" in
  publish-late|early-branch)
    ;;
  *)
    failures+=("invalid-branch-strategy($branch_strategy)")
    ;;
esac

if [[ "$state" == "done" ]]; then
  verification_status="$(lower "$(section_key_value "$TASK_FILE" "## Verification Status" "verification-status")")"
  verification_note="$(section_key_value "$TASK_FILE" "## Verification Status" "verification-note")"
  verification_at="$(section_key_value "$TASK_FILE" "## Verification Status" "verification-at-utc")"
  verification_fingerprint="$(section_key_value "$TASK_FILE" "## Verification Status" "verification-fingerprint")"

  scope_status="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-status")")"
  scope_note="$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-note")"
  scope_at="$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-at-utc")"
  scope_fingerprint="$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-fingerprint")"

  quality_status="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-status")")"
  quality_note="$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-note")"
  quality_at="$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-at-utc")"
  quality_fingerprint="$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-fingerprint")"
  current_fingerprint="$(task_fingerprint "$TASK_ID")"

  if [[ "$verification_status" != "pass" ]]; then
    failures+=("done-task-requires-verification-pass")
  fi
  if placeholder_like "$verification_note"; then
    failures+=("missing-verification-note")
  fi
  if placeholder_like "$verification_at"; then
    failures+=("missing-verification-at-utc")
  fi
  if section_has_key "$TASK_FILE" "## Verification Status" "verification-fingerprint"; then
    if placeholder_like "$verification_fingerprint"; then
      failures+=("missing-verification-fingerprint")
    elif [[ "$verification_fingerprint" != "$current_fingerprint" ]]; then
      failures+=("stale-verification-fingerprint")
    fi
  fi
  if [[ "$scope_status" != "pass" ]]; then
    failures+=("done-task-requires-scope-review-pass")
  fi
  if placeholder_like "$scope_note"; then
    failures+=("missing-scope-review-note")
  fi
  if placeholder_like "$scope_at"; then
    failures+=("missing-scope-review-at-utc")
  fi
  if section_has_key "$TASK_FILE" "## Review Status" "scope-review-fingerprint"; then
    if placeholder_like "$scope_fingerprint"; then
      failures+=("missing-scope-review-fingerprint")
    elif [[ "$scope_fingerprint" != "$current_fingerprint" ]]; then
      failures+=("stale-scope-review-fingerprint")
    fi
  fi
  if [[ "$quality_status" != "pass" ]]; then
    failures+=("done-task-requires-quality-review-pass")
  fi
  if placeholder_like "$quality_note"; then
    failures+=("missing-quality-review-note")
  fi
  if placeholder_like "$quality_at"; then
    failures+=("missing-quality-review-at-utc")
  fi
  if section_has_key "$TASK_FILE" "## Review Status" "quality-review-fingerprint"; then
    if placeholder_like "$quality_fingerprint"; then
      failures+=("missing-quality-review-fingerprint")
    elif [[ "$quality_fingerprint" != "$current_fingerprint" ]]; then
      failures+=("stale-quality-review-fingerprint")
    fi
  fi
  case "$risk_level" in
    standard)
      for key in "reuse-review" "hardcoding-review" "tests-review" "request-scope-review" "architecture-review"; do
        value="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "$key")")"
        if [[ "$value" != "pass" ]]; then
          failures+=("done-task-requires-$key-pass")
        fi
      done
      ;;
    high-risk)
      for key in "reuse-review" "hardcoding-review" "tests-review" "request-scope-review" "architecture-review" "risk-controls-review"; do
        value="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "$key")")"
        if [[ "$value" != "pass" ]]; then
          failures+=("done-task-requires-$key-pass")
        fi
      done
      ;;
  esac

  for key in "summary" "follow-up"; do
    value="$(section_key_value "$TASK_FILE" "## Completion" "$key")"
    if placeholder_like "$value"; then
      failures+=("missing-completion-$key")
    fi
  done
fi

if [[ "$state" == "superseded" ]]; then
  for key in "summary" "follow-up"; do
    value="$(section_key_value "$TASK_FILE" "## Completion" "$key")"
    if placeholder_like "$value"; then
      failures+=("superseded-task-requires-$key")
    fi
  done
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] task"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] task"
