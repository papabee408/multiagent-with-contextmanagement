#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
TASK_FILE="$(task_file "$TASK_ID")"
METRICS_FILE="$(template_metrics_file)"

if [[ ! -f "$TASK_FILE" ]]; then
  echo "[ERROR] missing task file: docs/tasks/$TASK_ID.md" >&2
  exit 1
fi

if [[ "$(task_state "$TASK_ID")" != "done" ]]; then
  echo "[ERROR] task metrics are recorded only for completed tasks: $TASK_ID" >&2
  exit 1
fi

METRICS_HEADER="recorded_at_utc	task_id	risk_level	task_state	target_file_count	verification_command_count	changed_file_count	verification_status	scope_review_status	quality_review_status	independent_review_status	approved_at_utc	completed_at_utc"
ensure_tsv_header "$METRICS_FILE" "$METRICS_HEADER"
if awk -F'\t' -v task_id="$TASK_ID" 'NR > 1 && $2 == task_id { found = 1 } END { exit(found ? 0 : 1) }' "$METRICS_FILE"; then
  echo "[PASS] record-task-metrics"
  echo " - task=$TASK_ID"
  echo " - already-recorded=yes"
  exit 0
fi

target_count="$(target_files_from_task "$TASK_ID" | line_count)"
verification_count="$(verification_commands_from_task "$TASK_ID" | line_count)"
changed_count="$(non_internal_changed_files "$TASK_ID" | line_count)"
verification_status="$(lower "$(tsv_sanitize "$(receipt_value "$(verification_receipt_file "$TASK_ID")" "result")")")"
scope_review_status="$(lower "$(tsv_sanitize "$(receipt_value "$(scope_review_receipt_file "$TASK_ID")" "result")")")"
quality_review_status="$(lower "$(tsv_sanitize "$(receipt_value "$(quality_review_receipt_file "$TASK_ID")" "result")")")"
independent_review_status="$(lower "$(tsv_sanitize "$(receipt_value "$(independent_review_receipt_file "$TASK_ID")" "result")")")"
if [[ -z "$independent_review_status" ]]; then
  independent_review_status="n/a"
fi
approved_at="$(tsv_sanitize "$(section_key_value "$TASK_FILE" "## Approval" "approved-at-utc")")"
completed_at="$(tsv_sanitize "$(section_key_value "$TASK_FILE" "## Status" "updated-at-utc")")"
if [[ -z "$completed_at" ]]; then
  completed_at="$(utc_now)"
fi

TMP_FILE="$(mktemp)"
cp "$METRICS_FILE" "$TMP_FILE"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(utc_now)" \
  "$(tsv_sanitize "$TASK_ID")" \
  "$(tsv_sanitize "$(task_risk_level "$TASK_ID")")" \
  "$(tsv_sanitize "$(task_state "$TASK_ID")")" \
  "$target_count" \
  "$verification_count" \
  "$changed_count" \
  "${verification_status:-unknown}" \
  "${scope_review_status:-unknown}" \
  "${quality_review_status:-unknown}" \
  "${independent_review_status:-unknown}" \
  "${approved_at:-unknown}" \
  "$completed_at" >> "$TMP_FILE"

mv "$TMP_FILE" "$METRICS_FILE"

echo "[PASS] record-task-metrics"
echo " - task=$TASK_ID"
