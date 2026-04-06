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
  planning|awaiting_approval|approved|in_progress|review|blocked|done)
    ;;
  *)
    failures+=("invalid-state($state)")
    ;;
esac

risk_level="$(lower "$(section_key_value "$TASK_FILE" "## Status" "risk-level")")"
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
  if [[ "$path" == /* ]]; then
    failures+=("absolute-target-file($path)")
  fi
  for seen in "${seen_targets[@]-}"; do
    if [[ "$seen" == "$path" ]]; then
      failures+=("duplicate-target-file($path)")
    fi
  done
  seen_targets+=("$path")
done < <(target_files_from_task "$TASK_ID")
if [[ "$target_count" == "0" ]]; then
  failures+=("missing-target-files")
fi

out_of_scope="$(section_bullet_values "$TASK_FILE" "## Out of Scope" | head -n 1)"
if placeholder_like "$out_of_scope"; then
  failures+=("missing-out-of-scope")
fi

for key in \
  "unrelated changes allowed" \
  "incidental refactors allowed"; do
  value="$(section_key_value "$TASK_FILE" "## Scope Guardrails" "$key")"
  if placeholder_like "$value"; then
    failures+=("missing-$key")
  fi
done

for key in \
  "unrelated changes allowed" \
  "incidental refactors allowed"; do
  value="$(lower "$(section_key_value "$TASK_FILE" "## Scope Guardrails" "$key")")"
  case "$value" in
    yes|no)
      ;;
    *)
      failures+=("invalid-$key($value)")
      ;;
  esac
done

for key in \
  "existing abstractions to reuse" \
  "config/constants to centralize" \
  "side effects to avoid"; do
  value="$(section_key_value "$TASK_FILE" "## Reuse and Constraints" "$key")"
  if placeholder_like "$value"; then
    failures+=("missing-$key")
  fi
done

for key in \
  "sensitive areas touched" \
  "extra checks before merge"; do
  value="$(section_key_value "$TASK_FILE" "## Risk Controls" "$key")"
  if placeholder_like "$value"; then
    failures+=("missing-$key")
  fi
done

if [[ "$risk_level" == "high-risk" ]]; then
  sensitive_areas="$(lower "$(section_key_value "$TASK_FILE" "## Risk Controls" "sensitive areas touched")")"
  extra_checks="$(lower "$(section_key_value "$TASK_FILE" "## Risk Controls" "extra checks before merge")")"
  if [[ "$sensitive_areas" == "none" ]]; then
    failures+=("high-risk-sensitive-areas-required")
  fi
  if [[ "$extra_checks" == "none" ]]; then
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

for key in "current focus" "next action" "known risks"; do
  value="$(section_key_value "$TASK_FILE" "## Session Resume" "$key")"
  if placeholder_like "$value"; then
    failures+=("missing-session-resume-$key")
  fi
done

if [[ "$state" == "done" ]]; then
  tracked_verification_receipt="$(tracked_verification_receipt_file "$TASK_ID")"
  tracked_scope_receipt="$(tracked_scope_review_receipt_file "$TASK_ID")"
  tracked_quality_receipt="$(tracked_quality_review_receipt_file "$TASK_ID")"
  tracked_independent_receipt="$(tracked_independent_review_receipt_file "$TASK_ID")"
  scope_review_status="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-status")")"
  quality_review_status="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-status")")"
  scope_review_note="$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-note")"
  quality_review_note="$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-note")"
  scope_review_fingerprint="$(section_key_value "$TASK_FILE" "## Review Status" "scope-review-fingerprint")"
  quality_review_fingerprint="$(section_key_value "$TASK_FILE" "## Review Status" "quality-review-fingerprint")"
  independent_review_status="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "independent-review-status")")"
  independent_review_note="$(section_key_value "$TASK_FILE" "## Review Status" "independent-review-note")"
  independent_reviewer="$(section_key_value "$TASK_FILE" "## Review Status" "independent-reviewer")"
  independent_review_fingerprint="$(section_key_value "$TASK_FILE" "## Review Status" "independent-review-fingerprint")"
  independent_review_proof_value="$(section_key_value "$TASK_FILE" "## Review Status" "independent-review-proof")"

  if [[ "$scope_review_status" != "pass" ]]; then
    failures+=("done-task-requires-scope-review-pass")
  fi
  if [[ "$quality_review_status" != "pass" ]]; then
    failures+=("done-task-requires-quality-review-pass")
  fi
  if placeholder_like "$scope_review_note"; then
    failures+=("missing-scope-review-note")
  fi
  if placeholder_like "$quality_review_note"; then
    failures+=("missing-quality-review-note")
  fi
  if placeholder_like "$scope_review_fingerprint"; then
    failures+=("missing-scope-review-fingerprint")
  fi
  if placeholder_like "$quality_review_fingerprint"; then
    failures+=("missing-quality-review-fingerprint")
  fi
  for tracked_receipt in "$tracked_verification_receipt" "$tracked_scope_receipt" "$tracked_quality_receipt"; do
    if [[ ! -f "$tracked_receipt" ]]; then
      failures+=("missing-tracked-receipt-$(basename "$tracked_receipt" .receipt)")
    fi
  done

  case "$risk_level" in
    trivial)
      ;;
    standard)
      if [[ "$independent_review_status" != "pass" ]]; then
        failures+=("done-task-requires-independent-review-pass")
      fi
      if placeholder_like "$independent_review_note"; then
        failures+=("missing-independent-review-note")
      fi
      if placeholder_like "$independent_reviewer"; then
        failures+=("missing-independent-reviewer")
      fi
      if placeholder_like "$independent_review_fingerprint"; then
        failures+=("missing-independent-review-fingerprint")
      fi
      if placeholder_like "$independent_review_proof_value"; then
        failures+=("missing-independent-review-proof")
      fi
      if [[ ! -f "$tracked_independent_receipt" ]]; then
        failures+=("missing-tracked-receipt-independent-review")
      fi
      for key in "reuse-review" "hardcoding-review" "tests-review" "request-scope-review"; do
        value="$(lower "$(section_key_value "$TASK_FILE" "## Review Status" "$key")")"
        if [[ "$value" != "pass" ]]; then
          failures+=("done-task-requires-$key-pass")
        fi
      done
      ;;
    high-risk)
      if [[ "$independent_review_status" != "pass" ]]; then
        failures+=("done-task-requires-independent-review-pass")
      fi
      if placeholder_like "$independent_review_note"; then
        failures+=("missing-independent-review-note")
      fi
      if placeholder_like "$independent_reviewer"; then
        failures+=("missing-independent-reviewer")
      fi
      if placeholder_like "$independent_review_fingerprint"; then
        failures+=("missing-independent-review-fingerprint")
      fi
      if placeholder_like "$independent_review_proof_value"; then
        failures+=("missing-independent-review-proof")
      fi
      if [[ ! -f "$tracked_independent_receipt" ]]; then
        failures+=("missing-tracked-receipt-independent-review")
      fi
      for key in "reuse-review" "hardcoding-review" "tests-review" "request-scope-review" "risk-controls-review"; do
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

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] task"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] task"
