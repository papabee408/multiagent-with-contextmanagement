#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/context" \
  "$TMP_DIR/docs/features/feature-sync" \
  "$TMP_DIR/.context"

cp "$ROOT_DIR/scripts/sync-handoffs.sh" "$TMP_DIR/scripts/sync-handoffs.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
chmod +x "$TMP_DIR/scripts/sync-handoffs.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-sync
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

cat > "$TMP_DIR/docs/features/feature-sync/brief.md" <<'EOF'
# Feature Brief

## Feature ID
- `feature-id`: feature-sync

## Goal
- Keep handoff sync deterministic.

## Non-goals
- No unrelated workflow edits.

## Requirements (RQ)
- `RQ-001`: Sync handoff files from plan.md.
- `RQ-002`: Preserve manual notes and matrix rows when safe.

## Constraints
- Keep the fixture simple.

## Acceptance
- Handoffs and test-matrix are regenerated from plan.md.

## Workflow Mode
- mode: `full`
- rationale: sync should include reviewer/security handoffs for the default fixture.

## Execution Mode
- mode: `single`
- rationale: one lead agent owns the fixture while helper sub-agents stay optional

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: packet helper shell functions
- Values/config that must not be hardcoded: digest fields and RQ ids
EOF

cat > "$TMP_DIR/docs/features/feature-sync/plan.md" <<'EOF'
# Feature Plan

## Scope
- target files:
  - `src/feature-sync.mjs`
  - `tests/feature-sync.test.mjs`
- out-of-scope files:
  - `README.md`

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2

## Architecture Notes
- target layer / owning module: workflow sync helpers stay under `scripts/`
- dependency constraints / forbidden imports: shell-only fixture, no external services
- shared logic or component placement: packet parsing helpers stay shared

## Reuse and Config Plan
- existing abstractions to reuse: existing packet helper shell functions
- extraction candidates for shared component/helper/module: keep future sync helpers shared
- constants/config/env to centralize: digest fields and feature ids
- hardcoded values explicitly allowed: markdown section titles

## Execution Strategy
- implementer mode: `parallel`
- merge owner: `implementer`
- shared files reserved for parent:
  - `src/feature-sync.mjs`

## Task Cards
### Task 1
- files: `docs/features/feature-sync/*.md`
- change: regenerate handoff files from plan metadata
- done when: handoff files reflect plan.md

### Task 2
- files: `docs/features/feature-sync/test-matrix.md`
- change: keep matrix rows aligned to RQ ids
- done when: matrix rows match the brief requirement list
EOF

cd "$TMP_DIR"

bash scripts/sync-handoffs.sh feature-sync >/dev/null

grep -Fq '## Source Digest' docs/features/feature-sync/implementer-handoff.md
grep -Fq -- '- workflow mode: full' docs/features/feature-sync/implementer-handoff.md
grep -Fq -- '- execution mode: single' docs/features/feature-sync/implementer-handoff.md
grep -Fq -- '- implementer mode: parallel' docs/features/feature-sync/implementer-handoff.md
grep -Fq -- '- brief-sha:' docs/features/feature-sync/tester-handoff.md
grep -Fq -- '- test edit policy: implementer owns baseline test updates; tester may strengthen `tests/**` only when coverage gaps remain after implementation' docs/features/feature-sync/tester-handoff.md
grep -Fq -- '- approval target:' docs/features/feature-sync/reviewer-handoff.md
grep -Fq -- '- reuse / componentization:' docs/features/feature-sync/reviewer-handoff.md
grep -Fq -- '- performance / waste watchpoints:' docs/features/feature-sync/reviewer-handoff.md
grep -Fq '| RQ-001 |' docs/features/feature-sync/test-matrix.md
grep -Fq '| RQ-002 |' docs/features/feature-sync/test-matrix.md
grep -Fq -- '- status: `DRAFT`' docs/features/feature-sync/test-matrix.md

perl -0pi -e 's/- status: `DRAFT`/- status: `VERIFIED`/' docs/features/feature-sync/test-matrix.md
perl -0pi -e 's#\| RQ-001 \|  \|  \|  \|  \|  \|#| RQ-001 | covered | covered | covered | tests/feature-sync.test.mjs | VERIFIED |#' \
  docs/features/feature-sync/test-matrix.md
perl -0pi -e 's#\| RQ-002 \|  \|  \|  \|  \|  \|#| RQ-002 | covered | covered | covered | tests/feature-sync.test.mjs | VERIFIED |#' \
  docs/features/feature-sync/test-matrix.md
bash scripts/sync-handoffs.sh feature-sync >/dev/null
grep -Fq -- '- status: `VERIFIED`' docs/features/feature-sync/test-matrix.md

perl -0pi -e 's/shell-only fixture, no external services/shell-only fixture with changed dependency constraint/' docs/features/feature-sync/plan.md
bash scripts/sync-handoffs.sh feature-sync >/dev/null
grep -Fq -- '- status: `DRAFT`' docs/features/feature-sync/test-matrix.md
plan_sha="$(shasum -a 256 docs/features/feature-sync/plan.md | awk '{print $1}')"
grep -Fq -- "- plan-sha: $plan_sha" docs/features/feature-sync/tester-handoff.md

perl -0pi -e 's/- status: `DRAFT`/- status: `VERIFIED`/' docs/features/feature-sync/test-matrix.md
perl -0pi -e 's#\| RQ-001 \| covered \| covered \| covered \| tests/feature-sync.test.mjs \| VERIFIED \|#| RQ-001 | covered | covered | covered | tests/feature-sync.test.mjs | VERIFIED |#' \
  docs/features/feature-sync/test-matrix.md
perl -0pi -e 's/Keep handoff sync deterministic./Keep handoff sync deterministic even after brief updates./' docs/features/feature-sync/brief.md
bash scripts/sync-handoffs.sh feature-sync >/dev/null
grep -Fq -- '- status: `DRAFT`' docs/features/feature-sync/test-matrix.md

echo "[PASS] sync-handoffs smoke"
