#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FEATURE_ID="${1:-}"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"

if [[ -z "$FEATURE_ID" ]]; then
  if [[ -f "$ACTIVE_FEATURE_FILE" ]]; then
    FEATURE_ID="$(tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE")"
  fi
fi

if [[ -z "$FEATURE_ID" ]]; then
  echo "Usage: scripts/gates/run.sh <feature-id>"
  echo "Or set active feature in .context/active_feature"
  exit 1
fi

checks=(
  "packet:scripts/gates/check-packet.sh"
  "role-chain:scripts/gates/check-role-chain.sh"
  "test-matrix:scripts/gates/check-test-matrix.sh"
  "scope:scripts/gates/check-scope.sh"
  "file-size:scripts/gates/check-file-size.sh"
  "tests:scripts/gates/check-tests.sh"
  "secrets:scripts/gates/check-secrets.sh"
)

fails=()

for entry in "${checks[@]}"; do
  name="${entry%%:*}"
  cmd="${entry#*:}"

  echo ""
  echo "== Gate: $name =="
  if "$ROOT_DIR/$cmd" "$FEATURE_ID"; then
    :
  else
    fails+=("$name")
  fi
done

echo ""
if [[ ${#fails[@]} -gt 0 ]]; then
  echo "Gate Summary: FAIL"
  printf ' - %s\n' "${fails[@]}"
  exit 1
fi

echo "Gate Summary: PASS"
