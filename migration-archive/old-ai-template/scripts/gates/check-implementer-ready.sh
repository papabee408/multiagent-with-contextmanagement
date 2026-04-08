#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"
FEATURE_ID=""

usage() {
  cat <<'EOF'
Usage:
  scripts/gates/check-implementer-ready.sh [--feature <feature-id>]
EOF
}

resolve_feature_id_or_exit() {
  local feature_id="${1:-}"

  if [[ -n "$feature_id" ]]; then
    printf '%s' "$feature_id"
    return 0
  fi

  if [[ -f "$ACTIVE_FEATURE_FILE" ]]; then
    feature_id="$(tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE")"
  fi

  if [[ -z "$feature_id" ]]; then
    echo "[ERROR] feature-id is required. Set .context/active_feature or pass --feature." >&2
    exit 1
  fi

  printf '%s' "$feature_id"
}

run_gate_or_collect_failure() {
  local gate_name="$1"
  local gate_script="$ROOT_DIR/scripts/gates/check-${gate_name}.sh"
  local output=""

  if output="$(bash "$gate_script" "$FEATURE_ID" 2>&1)"; then
    return 0
  fi

  if [[ -n "$output" ]]; then
    printf '%s\n' "$output"
  fi
  failures+=("$gate_name")
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      FEATURE_ID="${2:-}"
      if [[ -z "$FEATURE_ID" ]]; then
        echo "[ERROR] --feature requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unexpected argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

FEATURE_ID="$(resolve_feature_id_or_exit "$FEATURE_ID")"
failures=()

run_gate_or_collect_failure "brief" || true
run_gate_or_collect_failure "plan" || true
run_gate_or_collect_failure "handoffs" || true

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] implementer-ready"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] implementer-ready"
