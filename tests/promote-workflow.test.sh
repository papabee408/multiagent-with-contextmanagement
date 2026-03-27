#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/context" \
  "$TMP_DIR/docs/features/feature-1" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/promote-workflow.sh" "$TMP_DIR/scripts/promote-workflow.sh"
cp "$ROOT_DIR/scripts/workflow-mode.sh" "$TMP_DIR/scripts/workflow-mode.sh"
cp "$ROOT_DIR/scripts/execution-mode.sh" "$TMP_DIR/scripts/execution-mode.sh"
cp "$ROOT_DIR/scripts/sync-handoffs.sh" "$TMP_DIR/scripts/sync-handoffs.sh"
cp "$ROOT_DIR/scripts/_run_log_helpers.sh" "$TMP_DIR/scripts/_run_log_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
chmod +x \
  "$TMP_DIR/scripts/promote-workflow.sh" \
  "$TMP_DIR/scripts/workflow-mode.sh" \
  "$TMP_DIR/scripts/execution-mode.sh" \
  "$TMP_DIR/scripts/sync-handoffs.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/docs/context/PROJECT.md" <<'EOF'
# Project Brief
EOF

cat > "$TMP_DIR/docs/context/ARCHITECTURE.md" <<'EOF'
# Architecture Boundaries
EOF

cat > "$TMP_DIR/docs/context/GATES.md" <<'EOF'
# Gates
EOF

cat > "$TMP_DIR/docs/features/feature-1/brief.md" <<'EOF'
# Feature Brief

## Feature ID
- `feature-id`: feature-1

## Goal
- Keep workflow promotion in-place.

## Non-goals
- No unrelated script changes.

## Requirements (RQ)
- `RQ-001`: Promote trivial workflows without changing feature-id.

## Constraints
- Keep the fixture minimal.

## Acceptance
- Promotion updates workflow metadata and regenerated handoffs.

## Workflow Mode
- mode: `trivial`
- rationale: tiny request keeps tester/reviewer/security out of the initial loop

## Execution Mode
- mode: `single`
- rationale: one lead agent owns the fixture while helper sub-agents stay optional

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: workflow promotion helper scripts
- Values/config that must not be hardcoded: workflow mode names
EOF

cat > "$TMP_DIR/docs/features/feature-1/plan.md" <<'EOF'
# Feature Plan

## Scope
- target files:
  - `src/feature-1.mjs`
- out-of-scope files:
  - `README.md`

## RQ -> Task Mapping
- `RQ-001` -> Task 1

## Architecture Notes
- target layer / owning module: scripts and feature packet docs
- dependency constraints / forbidden imports: shell-only fixture
- shared logic or component placement: shared packet helpers remain under scripts

## Reuse and Config Plan
- existing abstractions to reuse: packet helper shell functions
- extraction candidates for shared component/helper/module: none
- constants/config/env to centralize: workflow mode names
- hardcoded values explicitly allowed: markdown section titles

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none

## Task Cards
### Task 1
- files: `docs/features/feature-1/*.md`
- change: keep workflow metadata in sync
- done when: brief, handoffs, and test-matrix reflect the promoted mode
EOF

cd "$TMP_DIR"

bash scripts/promote-workflow.sh --feature feature-1 full --reason "risk expanded after implementation touched config and review is now required"
grep -Fq -- '- mode: `full`' docs/features/feature-1/brief.md
grep -Fq -- '- workflow mode: full' docs/features/feature-1/reviewer-handoff.md
grep -Fq -- '- owner-verify: `tester`' docs/features/feature-1/test-matrix.md

if bash scripts/promote-workflow.sh --feature feature-1 trivial --reason "downgrade should be rejected" >/dev/null 2>&1; then
  echo "[FAIL] promote-workflow should reject downward changes"
  exit 1
fi

echo "[PASS] promote-workflow smoke"
