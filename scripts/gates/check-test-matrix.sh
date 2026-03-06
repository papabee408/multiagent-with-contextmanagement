#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh" "${1:-}"

BRIEF_FILE="$FEATURE_DIR/brief.md"
TEST_MATRIX_FILE="$FEATURE_DIR/test-matrix.md"

trim() {
  local value="$1"
  printf '%s' "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

matrix_status_value() {
  awk '
    $0 == "## Status" { in_status = 1; next }
    in_status && /^## / { in_status = 0 }
    in_status && index($0, "- status:") == 1 {
      line = substr($0, length("- status:") + 1)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$TEST_MATRIX_FILE"
}

matrix_last_updated_value() {
  awk '
    $0 == "## Status" { in_status = 1; next }
    in_status && /^## / { in_status = 0 }
    in_status && index($0, "- last-updated-utc:") == 1 {
      line = substr($0, length("- last-updated-utc:") + 1)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$TEST_MATRIX_FILE"
}

is_valid_utc_timestamp() {
  local value="$1"
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

if [[ ! -f "$BRIEF_FILE" ]]; then
  echo "[FAIL] test-matrix: missing brief file ($BRIEF_FILE)"
  exit 1
fi

if [[ ! -f "$TEST_MATRIX_FILE" ]]; then
  echo "[FAIL] test-matrix: missing test-matrix file ($TEST_MATRIX_FILE)"
  exit 1
fi

failures=()
status_value="$(matrix_status_value)"
status_value="$(trim "$status_value")"
status_value_uc="$(printf '%s' "$status_value" | tr '[:lower:]' '[:upper:]')"
if [[ -z "$status_value" || "$status_value_uc" == "DRAFT" || "$status_value_uc" != "VERIFIED" ]]; then
  failures+=("status-must-be-VERIFIED")
fi

last_updated_value="$(matrix_last_updated_value)"
last_updated_value="$(trim "$last_updated_value")"
if [[ -z "$last_updated_value" ]]; then
  failures+=("missing-last-updated-utc")
elif ! is_valid_utc_timestamp "$last_updated_value"; then
  failures+=("invalid-last-updated-utc($last_updated_value)")
fi

brief_rq_tmp="$(mktemp)"
matrix_rows_tmp="$(mktemp)"
trap 'rm -f "$brief_rq_tmp" "$matrix_rows_tmp"' EXIT

awk '
  /^## Requirements \(RQ\)/ { in_rq = 1; next }
  /^## / && in_rq { in_rq = 0 }
  in_rq {
    while (match($0, /`RQ-[0-9]+`/)) {
      value = substr($0, RSTART + 1, RLENGTH - 2)
      print value
      $0 = substr($0, RSTART + RLENGTH)
    }
  }
' "$BRIEF_FILE" | sed '/^$/d' | sort -u > "$brief_rq_tmp"

awk -F'|' '
  /^\|[[:space:]]*RQ-[0-9]+[[:space:]]*\|/ {
    rq = $2
    normal = $3
    error = $4
    boundary = $5
    test_file = $6
    status = $7
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", rq)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", normal)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", error)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", boundary)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", test_file)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
    print rq "\t" normal "\t" error "\t" boundary "\t" test_file "\t" status
  }
' "$TEST_MATRIX_FILE" > "$matrix_rows_tmp"

if [[ ! -s "$matrix_rows_tmp" ]]; then
  failures+=("missing-rq-rows")
fi

while IFS= read -r rq; do
  [[ -n "$rq" ]] || continue
  if ! awk -F'\t' -v rq="$rq" '$1 == rq { found = 1 } END { exit(found ? 0 : 1) }' "$matrix_rows_tmp"; then
    failures+=("missing-row($rq)")
  fi
done < "$brief_rq_tmp"

declare -a seen_rqs=()
while IFS=$'\t' read -r rq normal error boundary test_file row_status; do
  [[ -n "$rq" ]] || continue

  for seen_rq in "${seen_rqs[@]-}"; do
    if [[ "$rq" == "$seen_rq" ]]; then
      failures+=("duplicate-row($rq)")
    fi
  done
  seen_rqs+=("$rq")

  if [[ -z "$normal" ]]; then
    failures+=("$rq:missing-normal")
  fi
  if [[ -z "$error" ]]; then
    failures+=("$rq:missing-error")
  fi
  if [[ -z "$boundary" ]]; then
    failures+=("$rq:missing-boundary")
  fi
  if [[ -z "$test_file" ]]; then
    failures+=("$rq:missing-test-file")
  fi

  row_status_uc="$(printf '%s' "$row_status" | tr '[:lower:]' '[:upper:]')"
  if [[ -z "$row_status" ]]; then
    failures+=("$rq:missing-status")
  elif [[ "$row_status_uc" != "VERIFIED" ]]; then
    failures+=("$rq:status-must-be-VERIFIED($row_status)")
  fi
done < "$matrix_rows_tmp"

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] test-matrix"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] test-matrix"
