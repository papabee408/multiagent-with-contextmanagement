#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/features/feature-1"

cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
cp "$ROOT_DIR/scripts/gates/check-role-chain.sh" "$TMP_DIR/scripts/gates/check-role-chain.sh"
cp "$ROOT_DIR/scripts/gates/check-test-matrix.sh" "$TMP_DIR/scripts/gates/check-test-matrix.sh"

cat > "$TMP_DIR/docs/features/feature-1/brief.md" <<'EOF'
# Feature Brief

## Requirements (RQ)
- `RQ-001`: First requirement
- `RQ-002`: Second requirement
EOF

cat > "$TMP_DIR/docs/features/feature-1/plan.md" <<'EOF'
# Feature Plan

## Scope
- target files:
  - `builder/src/example.mjs`
  - `tests/unit/example.test.mjs`
- out-of-scope files:
  - `docs/README.md`
EOF

cat > "$TMP_DIR/docs/features/feature-1/run-log.md" <<'EOF'
# Run Log

## Status
- feature-id: feature-1
- overall: `DONE`

## Dispatch Monitor
- current-role: security
- current-status: `DONE`
- started-at-utc: 2026-03-06 10:00:00Z
- last-progress-at-utc: 2026-03-06 10:01:00Z
- interrupt-after-utc: 2026-03-06 10:02:00Z
- last-progress: ran `scripts/gates/run.sh feature-1`

## Role Outputs
### orchestrator
- agent-id: orch-101
- scope: docs/features/feature-1/run-log.md
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: updated run-log and final summary
- next_action: planner

### planner
- agent-id: plan-101
- scope: docs/features/feature-1/plan.md, docs/features/feature-1/test-matrix.md
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: wrote plan.md target files and seeded test-matrix rows
- next_action: implementer

### implementer
- agent-id: impl-101
- scope: builder/src/example.mjs, tests/unit/example.test.mjs
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: changed builder/src/example.mjs and tests/unit/example.test.mjs
- next_action: tester

### tester
- agent-id: test-101
- scope: tests/unit/example.test.mjs, docs/features/feature-1/test-matrix.md
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: ran scripts/gates/check-tests.sh and updated test-matrix
- next_action: gate-checker

### gate-checker
- agent-id: gate-101
- scope: scripts/gates/run.sh
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: ran scripts/gates/run.sh feature-1
- next_action: reviewer

### reviewer
- agent-id: review-101
- scope: builder/src/example.mjs
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: reviewed diff and gate output
- next_action: security

### security
- agent-id: sec-101
- scope: builder/src/example.mjs
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: checked validation and secrets paths
- next_action: complete
EOF

cat > "$TMP_DIR/docs/features/feature-1/test-matrix.md" <<'EOF'
# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-06 10:01:00Z

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | covered | covered | covered | tests/unit/example.test.mjs | VERIFIED |
| RQ-002 | covered | covered | covered | tests/unit/example.test.mjs | VERIFIED |
EOF

replace_in_file() {
  local path="$1"
  local search="$2"
  local replace="$3"
  SEARCH_TEXT="$search" REPLACE_TEXT="$replace" perl -0pi -e 's/\Q$ENV{SEARCH_TEXT}\E/$ENV{REPLACE_TEXT}/g' "$path"
}

cd "$TMP_DIR"

bash scripts/gates/check-role-chain.sh feature-1 >/dev/null
bash scripts/gates/check-test-matrix.sh feature-1 >/dev/null

replace_in_file "docs/features/feature-1/test-matrix.md" '`VERIFIED`' '`DRAFT`'
if bash scripts/gates/check-test-matrix.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected DRAFT test-matrix to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/test-matrix.md" '`DRAFT`' '`VERIFIED`'

replace_in_file "docs/features/feature-1/test-matrix.md" '| RQ-002 | covered | covered | covered | tests/unit/example.test.mjs | VERIFIED |' '| RQ-002 | covered |  | covered | tests/unit/example.test.mjs | VERIFIED |'
if bash scripts/gates/check-test-matrix.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected incomplete RQ row to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/test-matrix.md" '| RQ-002 | covered |  | covered | tests/unit/example.test.mjs | VERIFIED |' '| RQ-002 | covered | covered | covered | tests/unit/example.test.mjs | VERIFIED |'

replace_in_file "docs/features/feature-1/run-log.md" '- last-progress: ran `scripts/gates/run.sh feature-1`' '- last-progress:'
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected missing dispatch progress to fail"
  exit 1
fi

echo "[PASS] gates smoke"
