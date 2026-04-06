#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

METRICS_FILE="$(template_metrics_file)"
FEEDBACK_FILE="$(template_feedback_file)"

echo "# Template Health Report"
echo

if [[ ! -f "$METRICS_FILE" ]]; then
  echo "- completed-tasks: 0"
  echo "- note: no task metrics recorded yet"
else
  awk -F'\t' '
    NR == 1 { next }
    {
      if ($4 != "done") {
        next
      }
      total += 1
      risk[$3] += 1
      ver[$8] += 1
      scope[$9] += 1
      quality[$10] += 1
      independent[$11] += 1
    }
    END {
      printf "%s\n", "- completed-tasks: " total
      printf "%s\n", "- risk-trivial: " (risk["trivial"] + 0)
      printf "%s\n", "- risk-standard: " (risk["standard"] + 0)
      printf "%s\n", "- risk-high-risk: " (risk["high-risk"] + 0)
      printf "%s\n", "- verification-pass-records: " (ver["pass"] + 0)
      printf "%s\n", "- scope-review-pass-records: " (scope["pass"] + 0)
      printf "%s\n", "- quality-review-pass-records: " (quality["pass"] + 0)
      printf "%s\n", "- independent-review-pass-records: " (independent["pass"] + 0)
    }
  ' "$METRICS_FILE"
fi

if [[ ! -f "$FEEDBACK_FILE" ]]; then
  echo "- feedback-records: 0"
  echo "- next-step: collect feedback with scripts/record-task-feedback.sh when you want speed, accuracy, or satisfaction data"
  exit 0
fi

awk -F'\t' '
  NR == 1 { next }
  {
    total += 1
    req[$4] += 1
    speed[$5] += 1
    accuracy[$6] += 1
    satisfaction[$7] += 1
  }
  END {
    printf "%s\n", "- feedback-records: " total
    printf "%s\n", "- requirements-fit-met: " (req["met"] + 0)
    printf "%s\n", "- requirements-fit-partial: " (req["partial"] + 0)
    printf "%s\n", "- requirements-fit-missed: " (req["missed"] + 0)
    printf "%s\n", "- speed-fast: " (speed["fast"] + 0)
    printf "%s\n", "- speed-ok: " (speed["ok"] + 0)
    printf "%s\n", "- speed-slow: " (speed["slow"] + 0)
    printf "%s\n", "- accuracy-high: " (accuracy["high"] + 0)
    printf "%s\n", "- accuracy-medium: " (accuracy["medium"] + 0)
    printf "%s\n", "- accuracy-low: " (accuracy["low"] + 0)
    printf "%s\n", "- satisfaction-satisfied: " (satisfaction["satisfied"] + 0)
    printf "%s\n", "- satisfaction-neutral: " (satisfaction["neutral"] + 0)
    printf "%s\n", "- satisfaction-unsatisfied: " (satisfaction["unsatisfied"] + 0)
  }
' "$FEEDBACK_FILE"

echo "- improvement-policy: explain proposed template changes simply, then wait for explicit user approval before editing the template"
