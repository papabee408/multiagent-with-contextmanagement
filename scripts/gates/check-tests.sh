#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="full"
FEATURE_ID=""
CACHE_ENABLED=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/gates/check-tests.sh [--feature|--infra|--full] [--feature-id <feature-id>]

Modes:
  --feature  Run feature-facing unit tests only.
  --infra    Run shell smoke/regression tests only.
  --full     Run both feature and infra tests. Default.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      MODE="feature"
      shift
      ;;
    --infra)
      MODE="infra"
      shift
      ;;
    --full)
      MODE="full"
      shift
      ;;
    --feature-id)
      FEATURE_ID="${2:-}"
      if [[ -z "$FEATURE_ID" ]]; then
        echo "[ERROR] --feature-id requires a value" >&2
        usage
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unsupported argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$FEATURE_ID" && -f "$ROOT_DIR/.context/active_feature" ]]; then
  FEATURE_ID="$(tr -d ' \n\r\t' < "$ROOT_DIR/.context/active_feature")"
fi

if [[ -n "$FEATURE_ID" && -d "$ROOT_DIR/docs/features/$FEATURE_ID" ]]; then
  source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"
  source "$ROOT_DIR/scripts/gates/_validation_cache.sh"
  CACHE_ENABLED=1
fi

cd "$ROOT_DIR"

write_feature_receipt_if_configured() {
  local result="$1"
  if [[ "$CACHE_ENABLED" != "1" ]]; then
    return 0
  fi

  fingerprint="$(feature_tests_fingerprint "$FEATURE_ID")"
  write_feature_test_receipt \
    "$FEATURE_ID" \
    "feature" \
    "$fingerprint" \
    "$result" \
    "bash scripts/gates/check-tests.sh --feature --feature-id $FEATURE_ID"
}

run_feature_tests() {
  echo "[INFO] running feature tests"
  if node --test tests/unit/*.test.mjs; then
    write_feature_receipt_if_configured "PASS"
    return 0
  fi

  write_feature_receipt_if_configured "FAIL"
  return 1
}

run_infra_tests() {
  echo "[INFO] running context-log tests"
  bash tests/context-log.test.sh

  echo "[INFO] running gate script tests"
  bash tests/gates.test.sh

  echo "[INFO] running dispatch heartbeat tests"
  bash tests/dispatch-heartbeat.test.sh

  echo "[INFO] running run-log wrapper tests"
  bash tests/run-log-ops.test.sh

  echo "[INFO] running sync handoff tests"
  bash tests/sync-handoffs.test.sh

  echo "[INFO] running workflow mode tests"
  bash tests/workflow-mode.test.sh

  echo "[INFO] running implementer subtask tests"
  bash tests/implementer-subtasks.test.sh

  echo "[INFO] running check-tests mode tests"
  bash tests/check-tests-modes.test.sh

  echo "[INFO] running gate cache tests"
  bash tests/gate-cache.test.sh
}

case "$MODE" in
  feature)
    run_feature_tests
    ;;
  infra)
    run_infra_tests
    ;;
  full)
    run_feature_tests
    run_infra_tests
    ;;
esac

echo "[PASS] tests"
