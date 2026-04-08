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

cp "$ROOT_DIR/scripts/implementer-subtasks.sh" "$TMP_DIR/scripts/implementer-subtasks.sh"
cp "$ROOT_DIR/scripts/_run_log_helpers.sh" "$TMP_DIR/scripts/_run_log_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
chmod +x \
  "$TMP_DIR/scripts/implementer-subtasks.sh"

cat > "$TMP_DIR/.context/active_feature" <<'EOF'
feature-1
EOF

cat > "$TMP_DIR/docs/features/feature-1/plan.md" <<'EOF'
# Feature Plan

## Scope
- target files:
  - `src/alpha.ts`
  - `src/beta.ts`
  - `tests/alpha.test.ts`
  - `tests/beta.test.ts`
- out-of-scope files:
  - `README.md`

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2

## Architecture Notes
- target layer / owning module: split independent modules under `src/`
- dependency constraints / forbidden imports: keep workers file-disjoint
- shared logic or component placement: shared helpers stay with parent implementer

## Reuse and Config Plan
- existing abstractions to reuse: existing task cards
- extraction candidates for shared component/helper/module: keep shared merge-only files in parent scope
- constants/config/env to centralize: none
- hardcoded values explicitly allowed: test fixture paths

## Execution Strategy
- implementer mode: `parallel`
- merge owner: `implementer`
- shared files reserved for parent:
  - `src/index.ts`

## Task Cards
### Task 1
- files:
  - `src/alpha.ts`
  - `tests/alpha.test.ts`
- change:
  - Update alpha flow.
- done when:
  - Alpha code and test pass.

### Task 2
- files:
  - `src/beta.ts`
  - `tests/beta.test.ts`
- change:
  - Update beta flow.
- done when:
  - Beta code and test pass.
EOF

cd "$TMP_DIR"

mode_output="$(bash scripts/implementer-subtasks.sh mode --feature feature-1)"
[[ "$mode_output" == "parallel" ]]

validate_output="$(bash scripts/implementer-subtasks.sh validate --feature feature-1)"
printf '%s\n' "$validate_output" | grep -Fq '[PASS] implementer-subtasks'

list_output="$(bash scripts/implementer-subtasks.sh list --feature feature-1)"
printf '%s\n' "$list_output" | grep -Fq 'task-card-count: 2'
printf '%s\n' "$list_output" | grep -Fq 'Task 1: src/alpha.ts, tests/alpha.test.ts'

perl -0pi -e 's#`src/beta.ts`#`src/alpha.ts`#g' docs/features/feature-1/plan.md
if bash scripts/implementer-subtasks.sh validate --feature feature-1 >/dev/null 2>&1; then
  echo "[FAIL] duplicate task ownership should fail parallel validation"
  exit 1
fi

echo "[PASS] implementer-subtasks smoke"
