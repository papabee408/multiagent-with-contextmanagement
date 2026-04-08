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

cp "$ROOT_DIR/scripts/execution-mode.sh" "$TMP_DIR/scripts/execution-mode.sh"
cp "$ROOT_DIR/scripts/_run_log_helpers.sh" "$TMP_DIR/scripts/_run_log_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
chmod +x "$TMP_DIR/scripts/execution-mode.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/docs/features/feature-1/brief.md" <<'EOF'
# Feature Brief

## Feature ID
- `feature-id`: feature-1

## Goal
- Keep execution mode switching deterministic.

## Non-goals
- No unrelated script changes.

## Requirements (RQ)
- `RQ-001`: Execution mode should be readable from brief.md.

## Constraints
- Keep the fixture minimal.

## Acceptance
- `execution-mode.sh` can read and rewrite execution mode fields.

## Workflow Mode
- mode: `lite`
- rationale: balanced fixture keeps tester active without reviewer/security

## Execution Mode
- mode: `single`
- rationale: one lead agent owns the feature while helper sub-agents stay optional

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: execution mode helper script
- Values/config that must not be hardcoded: execution mode names
EOF

cd "$TMP_DIR"

mode_output="$(bash scripts/execution-mode.sh show --feature feature-1)"
[[ "$mode_output" == "single" ]]

if bash scripts/execution-mode.sh set --feature feature-1 multi-agent --reason "user explicitly requested parallel role ownership" >/dev/null 2>&1; then
  echo "[FAIL] execution mode change should require explicit unlock"
  exit 1
fi

bash scripts/execution-mode.sh set --feature feature-1 --allow-change multi-agent --reason "user explicitly requested parallel role ownership"
grep -Fq -- '- mode: `multi-agent`' docs/features/feature-1/brief.md
grep -Fq -- '- rationale: user explicitly requested parallel role ownership' docs/features/feature-1/brief.md

echo "[PASS] execution-mode smoke"
