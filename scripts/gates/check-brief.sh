#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh" "${1:-}"

BRIEF_FILE="$FEATURE_DIR/brief.md"

section_first_line() {
  local section="$1"

  awk -v section="$section" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "") {
        print line
        exit
      }
    }
  ' "$BRIEF_FILE"
}

brief_section_value() {
  local section="$1"
  local key="$2"

  awk -v section="$section" -v key="$key" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section {
      prefix = "- " key ":"
      if (index($0, prefix) == 1) {
        line = substr($0, length(prefix) + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$BRIEF_FILE"
}

brief_feature_id() {
  awk '
    $0 == "## Feature ID" { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section && index($0, "- `feature-id`:") == 1 {
      line = substr($0, length("- `feature-id`:") + 1)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$BRIEF_FILE"
}

failures=()

if [[ ! -f "$BRIEF_FILE" ]]; then
  echo "[FAIL] brief: missing brief file ($BRIEF_FILE)"
  exit 1
fi

declared_feature_id="$(brief_feature_id)"
if [[ "$declared_feature_id" != "$FEATURE_ID" ]]; then
  failures+=("feature-id-mismatch($declared_feature_id)")
fi

risk_class="$(risk_class_from_brief)"
case "$risk_class" in
  trivial|standard|high-risk)
    ;;
  *)
    failures+=("invalid-risk-class($risk_class)")
    ;;
esac

risk_rationale="$(risk_rationale_from_brief)"
if is_placeholder_text "$risk_rationale"; then
  failures+=("missing-risk-rationale")
fi

workflow_mode="$(workflow_mode_from_brief)"
case "$workflow_mode" in
  trivial|lite|full)
    ;;
  *)
    failures+=("invalid-workflow-mode($workflow_mode)")
    ;;
esac

workflow_rationale="$(workflow_rationale_from_brief)"
if is_placeholder_text "$workflow_rationale"; then
  failures+=("missing-workflow-rationale")
fi

execution_mode="$(execution_mode_from_brief)"
case "$execution_mode" in
  single|multi-agent)
    ;;
  *)
    failures+=("invalid-execution-mode($execution_mode)")
    ;;
esac

execution_rationale="$(execution_rationale_from_brief)"
if is_placeholder_text "$execution_rationale"; then
  failures+=("missing-execution-rationale")
fi

if [[ "$risk_class" == "high-risk" && "$workflow_mode" != "full" ]]; then
  failures+=("high-risk-requires-full-workflow")
fi

if ! brief_has_risk_signals_section; then
  failures+=("missing-risk-signals-section")
else
  risk_signal_yes_count=0
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    value="$(risk_signal_value_from_brief "$key")"
    if [[ -z "$value" ]]; then
      failures+=("risk-signals:invalid-${key}")
      continue
    fi
    if [[ "$value" == "yes" ]]; then
      risk_signal_yes_count=$((risk_signal_yes_count + 1))
    fi
  done < <(risk_signal_keys)

  if (( risk_signal_yes_count > 0 )) && [[ "$risk_class" != "high-risk" ]]; then
    failures+=("high-risk-signals-require-high-risk-class")
  fi

  if (( risk_signal_yes_count > 0 )) && [[ "$workflow_mode" != "full" ]]; then
    failures+=("high-risk-signals-require-full-workflow")
  fi
fi

for section in "## Goal" "## Non-goals" "## Constraints" "## Acceptance" "## Risk Class" "## Workflow Mode" "## Execution Mode" "## Requirement Notes"; do
  value="$(section_first_line "$section")"
  if is_placeholder_text "$value"; then
    failures+=("missing-content(${section#\#\# })")
  fi
done

for key in \
  "External dependencies" \
  "Existing modules/components/constants to reuse" \
  "Values/config that must not be hardcoded"; do
  value="$(brief_section_value "## Requirement Notes" "$key")"
  if is_placeholder_text "$value"; then
    failures+=("requirement-notes:missing-${key// /-}")
  fi
done

rq_tmp="$(mktemp)"
trap 'rm -f "$rq_tmp"' EXIT
brief_rq_ids > "$rq_tmp"

if [[ ! -s "$rq_tmp" ]]; then
  failures+=("missing-rq")
fi

while IFS= read -r rq; do
  [[ -n "$rq" ]] || continue
  description="$(awk -v rq="$rq" '
    /^## Requirements \(RQ\)/ { in_rq = 1; next }
    /^## / && in_rq { in_rq = 0 }
    in_rq && index($0, "`" rq "`") {
      line = $0
      sub(/^.*:[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$BRIEF_FILE")"

  if is_placeholder_text "$description"; then
    failures+=("$rq:missing-description")
  fi
done < "$rq_tmp"

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] brief"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] brief"
