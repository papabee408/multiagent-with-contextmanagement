#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"
FEATURE_ID=""
REUSE_IF_VALID=0
GATE_MODE="full"

usage() {
  cat <<'EOF'
Usage:
  scripts/gates/run.sh [--fast] [--reuse-if-valid] <feature-id>
  scripts/gates/run.sh [--fast] [--reuse-if-valid]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast)
      GATE_MODE="fast"
      shift
      ;;
    --reuse-if-valid)
      REUSE_IF_VALID=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FEATURE_ID="${1:-}"
      shift
      ;;
  esac
done

if [[ -z "$FEATURE_ID" && -f "$ACTIVE_FEATURE_FILE" ]]; then
  FEATURE_ID="$(tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE")"
fi

if [[ -z "$FEATURE_ID" ]]; then
  usage
  echo "Or set active feature in .context/active_feature"
  exit 1
fi

source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"
source "$ROOT_DIR/scripts/gates/_validation_cache.sh"

full_checks=(
  "project-context:scripts/gates/check-project-context.sh"
  "packet:scripts/gates/check-packet.sh"
  "brief:scripts/gates/check-brief.sh"
  "plan:scripts/gates/check-plan.sh"
  "handoffs:scripts/gates/check-handoffs.sh"
  "role-chain:scripts/gates/check-role-chain.sh"
  "test-matrix:scripts/gates/check-test-matrix.sh"
  "scope:scripts/gates/check-scope.sh"
  "file-size:scripts/gates/check-file-size.sh"
  "tests:internal"
  "secrets:scripts/gates/check-secrets.sh"
)

fast_checks=(
  "project-context:scripts/gates/check-project-context.sh"
  "packet:scripts/gates/check-packet.sh"
  "brief:scripts/gates/check-brief.sh"
  "plan:scripts/gates/check-plan.sh"
  "handoffs:scripts/gates/check-handoffs.sh"
  "scope:scripts/gates/check-scope.sh"
  "file-size:scripts/gates/check-file-size.sh"
  "tests:internal"
  "secrets:scripts/gates/check-secrets.sh"
)

checks=("${full_checks[@]}")
if [[ "$GATE_MODE" == "fast" ]]; then
  checks=("${fast_checks[@]}")
fi

current_feature_tests_fingerprint="$(feature_tests_fingerprint "$FEATURE_ID")"
current_full_gate_fingerprint=""
if [[ "$GATE_MODE" == "full" ]]; then
  current_full_gate_fingerprint="$(full_gate_fingerprint "$FEATURE_ID")"
fi

reusable_feature_receipt() {
  local receipt_file
  receipt_file="$(feature_test_receipt_file "$FEATURE_ID")"

  [[ -f "$receipt_file" ]] || return 1
  [[ "$(json_receipt_field "$receipt_file" "kind")" == "feature-tests" ]] || return 1
  [[ "$(json_receipt_field "$receipt_file" "result")" == "PASS" ]] || return 1
  [[ "$(json_receipt_field "$receipt_file" "fingerprint")" == "$current_feature_tests_fingerprint" ]] || return 1

  printf '%s' "$receipt_file"
}

reuse_full_gate_receipt_if_current() {
  local receipt_file
  receipt_file="$(full_gate_receipt_file "$FEATURE_ID")"

  [[ -f "$receipt_file" ]] || return 1
  [[ "$(json_receipt_field "$receipt_file" "kind")" == "full-gate" ]] || return 1
  [[ "$(json_receipt_field "$receipt_file" "result")" == "PASS" ]] || return 1
  [[ "$(json_receipt_field "$receipt_file" "fingerprint")" == "$current_full_gate_fingerprint" ]] || return 1

  echo "[PASS] full gate receipt reused: $FEATURE_ID"
  return 0
}

run_tests_gate() {
  local receipt_file

  receipt_file="$(reusable_feature_receipt || true)"
  if [[ -n "$receipt_file" ]]; then
    echo "[INFO] reusing feature test receipt: $receipt_file"
  else
    bash "$ROOT_DIR/scripts/gates/check-tests.sh" --feature --feature-id "$FEATURE_ID"
  fi

  if [[ "$GATE_MODE" == "fast" ]]; then
    return 0
  fi

  bash "$ROOT_DIR/scripts/gates/check-tests.sh" --infra
}

if [[ "$GATE_MODE" == "full" && "$REUSE_IF_VALID" == "1" ]] && reuse_full_gate_receipt_if_current; then
  exit 0
fi

fails=()

for entry in "${checks[@]}"; do
  name="${entry%%:*}"
  cmd="${entry#*:}"

  echo ""
  echo "== Gate: $name =="
  case "$name" in
    tests)
      if run_tests_gate; then
        :
      else
        fails+=("$name")
      fi
      ;;
    *)
      if "$ROOT_DIR/$cmd" "$FEATURE_ID"; then
        :
      else
        fails+=("$name")
      fi
      ;;
  esac
done

echo ""
if [[ ${#fails[@]} -gt 0 ]]; then
  if [[ "$GATE_MODE" == "full" ]]; then
    write_full_gate_receipt \
      "$FEATURE_ID" \
      "$current_full_gate_fingerprint" \
      "FAIL" \
      "$current_feature_tests_fingerprint" \
      "scripts/gates/run.sh $FEATURE_ID"
  fi
  echo "Gate Summary: FAIL"
  printf ' - %s\n' "${fails[@]}"
  exit 1
fi

if [[ "$GATE_MODE" == "full" ]]; then
  write_full_gate_receipt \
    "$FEATURE_ID" \
    "$current_full_gate_fingerprint" \
    "PASS" \
    "$current_feature_tests_fingerprint" \
    "scripts/gates/run.sh $FEATURE_ID"
fi

echo "Gate Summary: PASS"
