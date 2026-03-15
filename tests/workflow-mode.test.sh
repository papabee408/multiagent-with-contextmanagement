#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/features/feature-1" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/workflow-mode.sh" "$TMP_DIR/scripts/workflow-mode.sh"
cp "$ROOT_DIR/scripts/_run_log_helpers.sh" "$TMP_DIR/scripts/_run_log_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
chmod +x \
  "$TMP_DIR/scripts/workflow-mode.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/docs/features/feature-1/brief.md" <<'EOF'
# Feature Brief

## Feature ID
- `feature-id`: feature-1

## Goal
- Keep workflow mode switching deterministic.

## Non-goals
- No unrelated script changes.

## Requirements (RQ)
- `RQ-001`: Workflow mode should be readable from brief.md.

## Constraints
- Keep the fixture minimal.

## Acceptance
- `workflow-mode.sh` can read and rewrite mode fields.

## Workflow Mode
- mode: `full`
- rationale: high-risk template change keeps reviewer/security enabled

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: workflow mode helper script
- Values/config that must not be hardcoded: workflow mode names
EOF

cd "$TMP_DIR"

mode_output="$(bash scripts/workflow-mode.sh show --feature feature-1)"
[[ "$mode_output" == "full" ]]

sequence_output="$(bash scripts/workflow-mode.sh role-sequence --feature feature-1)"
printf '%s\n' "$sequence_output" | grep -Fxq 'reviewer'
printf '%s\n' "$sequence_output" | grep -Fxq 'security'

bash scripts/workflow-mode.sh set --feature feature-1 lite --reason "docs-only request with gate-checker stop"
grep -Fq -- '- mode: `lite`' docs/features/feature-1/brief.md
grep -Fq -- '- rationale: docs-only request with gate-checker stop' docs/features/feature-1/brief.md

sequence_output="$(bash scripts/workflow-mode.sh role-sequence --feature feature-1)"
printf '%s\n' "$sequence_output" | grep -Fxq 'gate-checker'
if printf '%s\n' "$sequence_output" | grep -Fxq 'reviewer'; then
  echo "[FAIL] lite workflow should stop before reviewer"
  exit 1
fi

echo "[PASS] workflow-mode smoke"
