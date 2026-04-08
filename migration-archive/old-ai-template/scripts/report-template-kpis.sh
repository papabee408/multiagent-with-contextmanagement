#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURES_DIR="$ROOT_DIR/docs/features"
MODE="full"

usage() {
  cat <<'EOF'
Usage:
  scripts/report-template-kpis.sh [--maintenance-section]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --maintenance-section)
      MODE="maintenance"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unsupported argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

trim() {
  local value="${1:-}"
  printf '%s' "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

normalize_mode_token() {
  local value
  value="$(lower "$(trim "${1:-}")")"
  case "$value" in
    trivial|lite|full|single|multi-agent)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

normalize_risk_class_token() {
  local value
  value="$(lower "$(trim "${1:-}")")"
  case "$value" in
    trivial|standard|high-risk)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

default_workflow_for_risk() {
  case "$(normalize_risk_class_token "${1:-}")" in
    trivial)
      printf '%s' "trivial"
      ;;
    high-risk)
      printf '%s' "full"
      ;;
    *)
      printf '%s' "lite"
      ;;
  esac
}

workflow_target_pct() {
  case "$(normalize_mode_token "${1:-}")" in
    trivial)
      printf '%s' "10.0"
      ;;
    lite)
      printf '%s' "75.0"
      ;;
    full)
      printf '%s' "15.0"
      ;;
    *)
      printf '%s' "0.0"
      ;;
  esac
}

section_value() {
  local file="$1"
  local section="$2"
  local key="$3"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  awk -v section="$section" -v key="$key" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section {
      prefix = "- " key ":"
      if (index($0, prefix) == 1) {
        line = substr($0, length(prefix) + 1)
        gsub(/`/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

json_field() {
  local file="$1"
  local field="$2"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const field = process.argv[2];
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    if (Object.prototype.hasOwnProperty.call(data, field)) {
      process.stdout.write(String(data[field]));
    }
  ' "$file" "$field"
}

utc_to_epoch() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    printf '%s' ""
    return
  fi

  perl -MTime::Piece -e '
    my $value = shift;
    my $epoch = Time::Piece->strptime($value, "%Y-%m-%d %H:%M:%SZ")->epoch;
    print $epoch;
  ' "$value" 2>/dev/null || printf '%s' ""
}

now_utc() {
  date -u +"%Y-%m-%d %H:%M:%SZ"
}

format_pct() {
  local numerator="${1:-0}"
  local denominator="${2:-0}"

  if [[ "$denominator" == "0" ]]; then
    printf '%s' "n/a"
    return
  fi

  awk -v n="$numerator" -v d="$denominator" 'BEGIN { printf "%.1f%%", (n / d) * 100 }'
}

format_decimal() {
  local value="${1:-0}"
  awk -v value="$value" 'BEGIN { printf "%.1f", value }'
}

print_distribution_line() {
  local label="$1"
  local count="$2"
  local total="$3"
  printf -- '- %s: %s (%s)\n' "$label" "$count" "$(format_pct "$count" "$total")"
}

feature_dirs=()
if [[ -d "$FEATURES_DIR" ]]; then
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    feature_dirs+=("$dir")
  done < <(find "$FEATURES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '_template' | sort)
fi

total_packets=0
risk_trivial=0
risk_standard=0
risk_high_risk=0
workflow_trivial=0
workflow_lite=0
workflow_full=0
execution_single=0
execution_multi_agent=0
workflow_overrides=0
high_risk_total=0
high_risk_compliant=0
high_risk_missing_full=0
standard_or_trivial_in_full=0
full_gate_pass=0
full_gate_fail=0
full_gate_missing=0
span_samples=0
span_minutes_total=0

if (( ${#feature_dirs[@]} > 0 )); then
for feature_dir in "${feature_dirs[@]}"; do
  total_packets=$((total_packets + 1))

  feature_id="$(basename "$feature_dir")"
  brief_file="$feature_dir/brief.md"
  run_log_file="$feature_dir/run-log.md"
  planner_receipt="$feature_dir/artifacts/roles/planner.json"
  gate_checker_receipt="$feature_dir/artifacts/roles/gate-checker.json"
  full_gate_receipt="$feature_dir/artifacts/gates/full.json"

  risk_class="$(normalize_risk_class_token "$(section_value "$brief_file" "## Risk Class" "class")")"
  workflow_mode="$(normalize_mode_token "$(section_value "$brief_file" "## Workflow Mode" "mode")")"
  execution_mode="$(normalize_mode_token "$(section_value "$brief_file" "## Execution Mode" "mode")")"

  case "$risk_class" in
    trivial) risk_trivial=$((risk_trivial + 1)) ;;
    standard) risk_standard=$((risk_standard + 1)) ;;
    high-risk) risk_high_risk=$((risk_high_risk + 1)) ;;
  esac

  case "$workflow_mode" in
    trivial) workflow_trivial=$((workflow_trivial + 1)) ;;
    lite) workflow_lite=$((workflow_lite + 1)) ;;
    full) workflow_full=$((workflow_full + 1)) ;;
  esac

  case "$execution_mode" in
    single) execution_single=$((execution_single + 1)) ;;
    multi-agent) execution_multi_agent=$((execution_multi_agent + 1)) ;;
  esac

  expected_workflow="$(default_workflow_for_risk "$risk_class")"
  if [[ -n "$workflow_mode" && -n "$expected_workflow" && "$workflow_mode" != "$expected_workflow" ]]; then
    workflow_overrides=$((workflow_overrides + 1))
  fi

  if [[ "$risk_class" == "high-risk" ]]; then
    high_risk_total=$((high_risk_total + 1))
    if [[ "$workflow_mode" == "full" ]]; then
      high_risk_compliant=$((high_risk_compliant + 1))
    else
      high_risk_missing_full=$((high_risk_missing_full + 1))
    fi
  fi

  if [[ "$workflow_mode" == "full" && "$risk_class" != "high-risk" ]]; then
    standard_or_trivial_in_full=$((standard_or_trivial_in_full + 1))
  fi

  if [[ -f "$full_gate_receipt" ]]; then
    gate_result="$(lower "$(json_field "$full_gate_receipt" "result")")"
    case "$gate_result" in
      pass)
        full_gate_pass=$((full_gate_pass + 1))
        ;;
      fail)
        full_gate_fail=$((full_gate_fail + 1))
        ;;
      *)
        full_gate_missing=$((full_gate_missing + 1))
        ;;
    esac
  else
    full_gate_missing=$((full_gate_missing + 1))
  fi

  planner_updated_at="$(json_field "$planner_receipt" "updated_at_utc")"
  gate_checker_updated_at="$(json_field "$gate_checker_receipt" "updated_at_utc")"
  planner_epoch="$(utc_to_epoch "$planner_updated_at")"
  gate_checker_epoch="$(utc_to_epoch "$gate_checker_updated_at")"
  if [[ -n "$planner_epoch" && -n "$gate_checker_epoch" ]] && (( gate_checker_epoch >= planner_epoch )); then
    span_samples=$((span_samples + 1))
    span_minutes_total="$(awk -v total="$span_minutes_total" -v start="$planner_epoch" -v end="$gate_checker_epoch" 'BEGIN { printf "%.6f", total + ((end - start) / 60) }')"
  fi
done
fi

average_span_minutes="n/a"
if (( span_samples > 0 )); then
  average_span_minutes="$(awk -v total="$span_minutes_total" -v count="$span_samples" 'BEGIN { printf "%.1f", total / count }')"
fi

print_report_body() {
  printf -- '- Feature packets: %s\n' "$total_packets"
  printf -- '- Workflow overrides: %s/%s (%s)\n' "$workflow_overrides" "$total_packets" "$(format_pct "$workflow_overrides" "$total_packets")"
  printf -- '- High-risk compliance: %s/%s (%s)\n' "$high_risk_compliant" "$high_risk_total" "$(format_pct "$high_risk_compliant" "$high_risk_total")"
  printf -- '- Full gate PASS coverage: %s/%s (%s)\n' "$full_gate_pass" "$total_packets" "$(format_pct "$full_gate_pass" "$total_packets")"
  printf -- '- Average planner-to-gate-checker minutes: %s (samples: %s)\n' "$average_span_minutes" "$span_samples"
  printf '\n### Risk Mix\n'
  print_distribution_line "trivial" "$risk_trivial" "$total_packets"
  print_distribution_line "standard" "$risk_standard" "$total_packets"
  print_distribution_line "high-risk" "$risk_high_risk" "$total_packets"
  printf '\n### Workflow Mix\n'
  print_distribution_line "trivial" "$workflow_trivial" "$total_packets"
  print_distribution_line "lite" "$workflow_lite" "$total_packets"
  print_distribution_line "full" "$workflow_full" "$total_packets"
  printf '\n### Execution Mix\n'
  print_distribution_line "single" "$execution_single" "$total_packets"
  print_distribution_line "multi-agent" "$execution_multi_agent" "$total_packets"
  printf '\n### Target Bands\n'
  printf -- '- trivial: target %s%%, actual %s\n' "$(workflow_target_pct "trivial")" "$(format_pct "$workflow_trivial" "$total_packets")"
  printf -- '- lite: target %s%%, actual %s\n' "$(workflow_target_pct "lite")" "$(format_pct "$workflow_lite" "$total_packets")"
  printf -- '- full: target %s%%, actual %s\n' "$(workflow_target_pct "full")" "$(format_pct "$workflow_full" "$total_packets")"
  printf '\n### Attention\n'
  printf -- '- high-risk-missing-full: %s\n' "$high_risk_missing_full"
  printf -- '- standard-or-trivial-in-full: %s\n' "$standard_or_trivial_in_full"
  printf -- '- full-gate-fail: %s\n' "$full_gate_fail"
  printf -- '- packets-without-pass-full-gate: %s\n' "$(( total_packets - full_gate_pass ))"
}

case "$MODE" in
  maintenance)
    print_report_body
    ;;
  *)
    cat <<EOF
# Template KPI Report

- Generated At (UTC): $(now_utc)
$(print_report_body)
EOF
    ;;
esac
