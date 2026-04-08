#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/record-task-feedback.sh <task-id> \
    --requirements-fit <met|partial|missed> \
    --speed <fast|ok|slow> \
    --accuracy <high|medium|low> \
    --satisfaction <satisfied|neutral|unsatisfied> \
    [--note "<free-form note>"]
EOF
}

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
shift || true

requirements_fit=""
speed=""
accuracy=""
satisfaction=""
note=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --requirements-fit)
      requirements_fit="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --speed)
      speed="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --accuracy)
      accuracy="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --satisfaction)
      satisfaction="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --note)
      note="$(trim "${2:-}")"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$requirements_fit" in
  met|partial|missed)
    ;;
  *)
    echo "[ERROR] --requirements-fit must be one of: met, partial, missed" >&2
    exit 1
    ;;
esac

case "$speed" in
  fast|ok|slow)
    ;;
  *)
    echo "[ERROR] --speed must be one of: fast, ok, slow" >&2
    exit 1
    ;;
esac

case "$accuracy" in
  high|medium|low)
    ;;
  *)
    echo "[ERROR] --accuracy must be one of: high, medium, low" >&2
    exit 1
    ;;
esac

case "$satisfaction" in
  satisfied|neutral|unsatisfied)
    ;;
  *)
    echo "[ERROR] --satisfaction must be one of: satisfied, neutral, unsatisfied" >&2
    exit 1
    ;;
esac

if [[ ! -f "$(task_file "$TASK_ID")" ]]; then
  echo "[ERROR] missing task file: docs/tasks/$TASK_ID.md" >&2
  exit 1
fi

FEEDBACK_FILE="$(template_feedback_file)"
ensure_tsv_header "$FEEDBACK_FILE" "recorded_at_utc	task_id	risk_level	requirements_fit	speed	accuracy	satisfaction	note"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$(utc_now)" \
  "$(tsv_sanitize "$TASK_ID")" \
  "$(tsv_sanitize "$(task_risk_level "$TASK_ID")")" \
  "$(tsv_sanitize "$requirements_fit")" \
  "$(tsv_sanitize "$speed")" \
  "$(tsv_sanitize "$accuracy")" \
  "$(tsv_sanitize "$satisfaction")" \
  "$(tsv_sanitize "$note")" >> "$FEEDBACK_FILE"

echo "[PASS] record-task-feedback"
echo " - task=$TASK_ID"
