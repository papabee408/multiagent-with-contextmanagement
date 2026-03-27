#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/scripts" \
  "$TMP_DIR/scripts/gates" \
  "$TMP_DIR/docs/context" \
  "$TMP_DIR/docs/features/feature-1"

cp "$ROOT_DIR/scripts/_role_receipt_helpers.sh" "$TMP_DIR/scripts/_role_receipt_helpers.sh"
cp "$ROOT_DIR/scripts/_git_change_helpers.sh" "$TMP_DIR/scripts/_git_change_helpers.sh"
cp "$ROOT_DIR/scripts/sync-handoffs.sh" "$TMP_DIR/scripts/sync-handoffs.sh"
cp "$ROOT_DIR/scripts/gates/_helpers.sh" "$TMP_DIR/scripts/gates/_helpers.sh"
cp "$ROOT_DIR/scripts/gates/check-project-context.sh" "$TMP_DIR/scripts/gates/check-project-context.sh"
cp "$ROOT_DIR/scripts/gates/check-packet.sh" "$TMP_DIR/scripts/gates/check-packet.sh"
cp "$ROOT_DIR/scripts/gates/check-brief.sh" "$TMP_DIR/scripts/gates/check-brief.sh"
cp "$ROOT_DIR/scripts/gates/check-plan.sh" "$TMP_DIR/scripts/gates/check-plan.sh"
cp "$ROOT_DIR/scripts/gates/check-handoffs.sh" "$TMP_DIR/scripts/gates/check-handoffs.sh"
cp "$ROOT_DIR/scripts/gates/check-role-chain.sh" "$TMP_DIR/scripts/gates/check-role-chain.sh"
cp "$ROOT_DIR/scripts/gates/check-test-matrix.sh" "$TMP_DIR/scripts/gates/check-test-matrix.sh"
chmod +x "$TMP_DIR/scripts/sync-handoffs.sh"

repo_slug="$(basename "$TMP_DIR")"

cat > "$TMP_DIR/docs/context/PROJECT.md" <<EOF
# Project Brief

## Identity
- project-name: Gate Test Repo
- repo-slug: $repo_slug
- product-type: test fixture

## Product
- Primary goal: verify gate scripts.
- Primary users: template maintainers.
- Success signals: shell gate checks pass and fail in the right places.

## Stack
- Runtime: shell
- Framework: none
- Data layer: none

## Constraints
- Keep fixtures minimal.
- Keep behavior deterministic.

## Working Agreements
- Update the gate fixtures when gate contracts change.
EOF

cat > "$TMP_DIR/docs/context/CONVENTIONS.md" <<'EOF'
# Coding Conventions

## Reuse First
- Reuse existing gate helpers before adding new scripts.

## Configuration and Constants
- Keep stable gate metadata in named fields.

## Components and Modules
- Separate gate parsing logic from fixtures.

## Naming and Data Shapes
- Keep RQ ids and role ids stable.

## Tests and Change Hygiene
- Every new gate must have a shell smoke test.
EOF

cat > "$TMP_DIR/docs/context/ARCHITECTURE.md" <<'EOF'
# Architecture Boundaries

## System Map
- Entry/Application layer: shell entrypoints
- Feature/Domain layer: gate parsing rules
- Infrastructure/Integration layer: git and filesystem access

## Layers
1. Entry layer orchestrates gate execution.

## Dependency Direction
- Allowed: entry -> gate scripts

## Placement Guide
1. New gate logic lives in `scripts/gates/`.
EOF

cat > "$TMP_DIR/docs/context/RULES.md" <<'EOF'
# Implementer Rules

## Scope and RQ
1. Keep changes mapped to requirements.

## Reuse and Hardcoding
1. Avoid duplicated gate logic and scattered literals.

## Architecture Fit
1. Keep parsing logic separate from orchestration.

## Testing
1. Update shell smoke tests when gates change.
EOF

cat > "$TMP_DIR/docs/context/GATES.md" <<'EOF'
# Gates
EOF

cat > "$TMP_DIR/docs/features/feature-1/brief.md" <<'EOF'
# Feature Brief

## Feature ID
- `feature-id`: feature-1

## Goal
- Keep gate fixtures representative and valid.

## Non-goals
- No unrelated production code changes.

## Requirements (RQ)
- `RQ-001`: Validate context docs and feature metadata completeness.
- `RQ-002`: Validate packet, handoff, role-chain, and test-matrix failures are caught.

## Constraints
- Keep the fixture repo minimal.

## Acceptance
- All target gates pass in the happy path.

## Workflow Mode
- mode: `full`
- rationale: reviewer and security stay required for the default gate fixture.

## Execution Mode
- mode: `multi-agent`
- rationale: gate fixture keeps per-role ownership distinct by default

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: gate helper shell functions
- Values/config that must not be hardcoded: role names, RQ ids, gate status fields
EOF

cat > "$TMP_DIR/docs/features/feature-1/plan.md" <<'EOF'
# Feature Plan

## Scope
- target files:
  - `src/example-module.mjs`
  - `tests/example-module.test.mjs`
- out-of-scope files:
  - `docs/README.md`

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2

## Architecture Notes
- target layer / owning module: gate fixtures live under `docs/features/**`
- dependency constraints / forbidden imports: shell gate checks must not depend on app runtime modules
- shared logic or component placement: shared parsing helpers stay in `scripts/gates/_helpers.sh`

## Reuse and Config Plan
- existing abstractions to reuse: shared gate helper functions
- extraction candidates for shared component/helper/module: keep any new parsing helpers in `_helpers.sh`
- constants/config/env to centralize: role names and required gate status strings
- hardcoded values explicitly allowed: markdown section titles required by the fixture

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none

## Task Cards
### Task 1
- files: `docs/context/*.md`
- change: keep project context and feature metadata valid
- done when: project-context and brief gates pass

### Task 2
- files: `docs/features/feature-1/*.md`
- change: keep packet, handoffs, role-chain, and test-matrix fixtures valid
- done when: packet, handoffs, role-chain, and test-matrix gates pass
EOF

bash "$TMP_DIR/scripts/sync-handoffs.sh" feature-1 >/dev/null

brief_sha="$(shasum -a 256 "$TMP_DIR/docs/features/feature-1/brief.md" | awk '{print $1}')"
plan_sha="$(shasum -a 256 "$TMP_DIR/docs/features/feature-1/plan.md" | awk '{print $1}')"

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
- scope: docs/features/feature-1/plan.md, docs/features/feature-1/implementer-handoff.md, docs/features/feature-1/tester-handoff.md, docs/features/feature-1/reviewer-handoff.md, docs/features/feature-1/security-handoff.md, docs/features/feature-1/test-matrix.md
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: wrote plan.md, handoff files, and seeded test-matrix rows
- next_action: implementer

### implementer
- agent-id: impl-101
- scope: src/example-module.mjs, tests/example-module.test.mjs
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: changed src/example-module.mjs and tests/example-module.test.mjs
- next_action: tester

### tester
- agent-id: test-101
- scope: docs/features/feature-1/test-matrix.md
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
- scope: src/example-module.mjs
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: reviewed diff and gate output
- next_action: security

### security
- agent-id: sec-101
- scope: src/example-module.mjs
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: checked validation and secrets paths
- next_action: complete
EOF

cd "$TMP_DIR"
git init -q
git config user.name "Codex Test"
git config user.email "codex-test@example.com"

mkdir -p "$TMP_DIR/docs/features/feature-1/artifacts/roles"

write_role_receipt() {
  local role="$1"
  local agent_id="$2"
  local scope="$3"
  local rq_covered="$4"
  local rq_missing="$5"
  local result="$6"
  local evidence="$7"
  local next_action="$8"
  local touched_files="$9"
  local approval_target_hash="${10:-}"

  FILE="$TMP_DIR/docs/features/feature-1/artifacts/roles/${role}.json" \
  ROLE_VALUE="$role" \
  AGENT_ID_VALUE="$agent_id" \
  SCOPE_VALUE="$scope" \
  RQ_COVERED_VALUE="$rq_covered" \
  RQ_MISSING_VALUE="$rq_missing" \
  RESULT_VALUE="$result" \
  EVIDENCE_VALUE="$evidence" \
  NEXT_ACTION_VALUE="$next_action" \
  TOUCHED_FILES_VALUE="$touched_files" \
  APPROVAL_TARGET_HASH_VALUE="$approval_target_hash" \
  node <<'EOF'
const fs = require("fs");

const parseTouchedFiles = (value) => {
  const raw = String(value || "").trim();
  if (!raw || raw === "[]") {
    return [];
  }
  return raw
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
};

const payload = {
  role: process.env.ROLE_VALUE,
  agent_id: process.env.AGENT_ID_VALUE,
  scope: process.env.SCOPE_VALUE,
  rq_covered: process.env.RQ_COVERED_VALUE,
  rq_missing: process.env.RQ_MISSING_VALUE,
  result: process.env.RESULT_VALUE,
  evidence: process.env.EVIDENCE_VALUE,
  next_action: process.env.NEXT_ACTION_VALUE,
  touched_files: parseTouchedFiles(process.env.TOUCHED_FILES_VALUE),
  input_digest: `digest-${process.env.ROLE_VALUE}`,
  updated_at_utc: "2026-03-06 10:01:00Z"
};

if (String(process.env.APPROVAL_TARGET_HASH_VALUE || "").trim()) {
  payload.approval_target_hash = process.env.APPROVAL_TARGET_HASH_VALUE.trim();
}

fs.writeFileSync(process.env.FILE, JSON.stringify(payload, null, 2) + "\n");
EOF
}

write_role_receipt "orchestrator" "orch-101" "docs/features/feature-1/run-log.md" "[RQ-001, RQ-002]" "[]" "PASS" "updated run-log and final summary" "planner" "[]"
write_role_receipt "planner" "plan-101" "docs/features/feature-1/plan.md, docs/features/feature-1/implementer-handoff.md, docs/features/feature-1/tester-handoff.md, docs/features/feature-1/reviewer-handoff.md, docs/features/feature-1/security-handoff.md, docs/features/feature-1/test-matrix.md" "[RQ-001, RQ-002]" "[]" "PASS" "wrote plan.md, handoff files, and seeded test-matrix rows" "implementer" "docs/features/feature-1/plan.md, docs/features/feature-1/implementer-handoff.md, docs/features/feature-1/tester-handoff.md, docs/features/feature-1/reviewer-handoff.md, docs/features/feature-1/security-handoff.md, docs/features/feature-1/test-matrix.md"
write_role_receipt "implementer" "impl-101" "src/example-module.mjs, tests/example-module.test.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "changed src/example-module.mjs and tests/example-module.test.mjs" "tester" "src/example-module.mjs, tests/example-module.test.mjs"
write_role_receipt "tester" "test-101" "docs/features/feature-1/test-matrix.md" "[RQ-001, RQ-002]" "[]" "PASS" "ran scripts/gates/check-tests.sh and updated test-matrix" "gate-checker" "docs/features/feature-1/test-matrix.md"
write_role_receipt "gate-checker" "gate-101" "scripts/gates/run.sh" "[RQ-001, RQ-002]" "[]" "PASS" "ran scripts/gates/run.sh feature-1" "reviewer" "[]"

cat > "$TMP_DIR/docs/features/feature-1/test-matrix.md" <<'EOF'
# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-06 10:01:00Z
- source-brief-sha: __BRIEF_SHA__
- source-plan-sha: __PLAN_SHA__

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | covered | covered | covered | tests/example-module.test.mjs | VERIFIED |
| RQ-002 | covered | covered | covered | tests/example-module.test.mjs | VERIFIED |
EOF

replace_in_file() {
  local path="$1"
  local search="$2"
  local replace="$3"
  SEARCH_TEXT="$search" REPLACE_TEXT="$replace" perl -0pi -e 's/\Q$ENV{SEARCH_TEXT}\E/$ENV{REPLACE_TEXT}/g' "$path"
}

replace_in_file "docs/features/feature-1/test-matrix.md" '__BRIEF_SHA__' "$brief_sha"
replace_in_file "docs/features/feature-1/test-matrix.md" '__PLAN_SHA__' "$plan_sha"
approval_target_hash_value="$(
  source "$TMP_DIR/scripts/gates/_helpers.sh" feature-1
  approval_target_hash
)"
write_role_receipt "reviewer" "review-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "reviewed diff and gate output" "security" "[]" "$approval_target_hash_value"
write_role_receipt "security" "sec-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "checked validation and secrets paths" "complete" "[]" "$approval_target_hash_value"

git add .
git commit -qm "fixture"

clean_changed_files="$(
  source "$TMP_DIR/scripts/gates/_helpers.sh" feature-1
  changed_files
)"
if [[ -n "$(printf '%s\n' "$clean_changed_files" | sed '/^$/d')" ]]; then
  echo "[FAIL] expected clean worktree to report no changed files"
  exit 1
fi

approval_target_hash_value="$(
  source "$TMP_DIR/scripts/gates/_helpers.sh" feature-1
  approval_target_hash
)"
write_role_receipt "reviewer" "review-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "reviewed diff and gate output" "security" "[]" "$approval_target_hash_value"
write_role_receipt "security" "sec-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "checked validation and secrets paths" "complete" "[]" "$approval_target_hash_value"

replace_in_file "docs/features/feature-1/run-log.md" '- current-status: `DONE`' '- current-status: `QUEUED`'
replace_in_file "docs/features/feature-1/run-log.md" '- started-at-utc: 2026-03-06 10:00:00Z' '- started-at-utc:'
replace_in_file "docs/features/feature-1/run-log.md" '- interrupt-after-utc: 2026-03-06 10:02:00Z' '- interrupt-after-utc:'
bash scripts/gates/check-role-chain.sh feature-1 >/dev/null
replace_in_file "docs/features/feature-1/run-log.md" '- current-status: `QUEUED`' '- current-status: `DONE`'
replace_in_file "docs/features/feature-1/run-log.md" '- started-at-utc:' '- started-at-utc: 2026-03-06 10:00:00Z'
replace_in_file "docs/features/feature-1/run-log.md" '- interrupt-after-utc:' '- interrupt-after-utc: 2026-03-06 10:02:00Z'

bash scripts/gates/check-project-context.sh >/dev/null
bash scripts/gates/check-packet.sh feature-1 >/dev/null
bash scripts/gates/check-brief.sh feature-1 >/dev/null
bash scripts/gates/check-plan.sh feature-1 >/dev/null
bash scripts/gates/check-handoffs.sh feature-1 >/dev/null
bash scripts/gates/check-role-chain.sh feature-1 >/dev/null
bash scripts/gates/check-test-matrix.sh feature-1 >/dev/null

replace_in_file "docs/features/feature-1/run-log.md" '- agent-id: gate-101' '- agent-id: impl-101'
write_role_receipt "gate-checker" "impl-101" "scripts/gates/run.sh" "[RQ-001, RQ-002]" "[]" "PASS" "ran scripts/gates/run.sh feature-1" "reviewer" "[]"
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected duplicate agent-id in multi-agent mode to fail role-chain"
  exit 1
fi
replace_in_file "docs/features/feature-1/run-log.md" '- agent-id: impl-101' '- agent-id: gate-101'
write_role_receipt "gate-checker" "gate-101" "scripts/gates/run.sh" "[RQ-001, RQ-002]" "[]" "PASS" "ran scripts/gates/run.sh feature-1" "reviewer" "[]"

replace_in_file "docs/context/PROJECT.md" "$repo_slug" 'context+MultiAgentDev'
if bash scripts/gates/check-project-context.sh >/dev/null 2>&1; then
  echo "[FAIL] expected stale repo slug to fail"
  exit 1
fi
replace_in_file "docs/context/PROJECT.md" 'context+MultiAgentDev' "$repo_slug"

replace_in_file "docs/features/feature-1/brief.md" '- External dependencies: none' '- External dependencies:'
if bash scripts/gates/check-brief.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected incomplete brief notes to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/brief.md" '- External dependencies:' '- External dependencies: none'

replace_in_file "docs/features/feature-1/plan.md" '- constants/config/env to centralize: role names and required gate status strings' '- constants/config/env to centralize:'
if bash scripts/gates/check-plan.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected incomplete reuse/config plan to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/plan.md" '- constants/config/env to centralize:' '- constants/config/env to centralize: role names and required gate status strings'

rm "docs/features/feature-1/reviewer-handoff.md"
if bash scripts/gates/check-packet.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected missing reviewer handoff file to fail packet gate"
  exit 1
fi
bash scripts/sync-handoffs.sh feature-1 >/dev/null

replace_in_file "docs/features/feature-1/tester-handoff.md" '- execution notes / commands: Run `scripts/gates/check-tests.sh`, then update `test-matrix.md` with the concrete test files you executed.' '- execution notes / commands:'
if bash scripts/gates/check-handoffs.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected incomplete tester handoff to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/tester-handoff.md" '- execution notes / commands:' '- execution notes / commands: Run `scripts/gates/check-tests.sh`, then update `test-matrix.md` with the concrete test files you executed.'
replace_in_file "docs/features/feature-1/implementer-handoff.md" '- execution mode: multi-agent' '- execution mode:'
if bash scripts/gates/check-handoffs.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected implementer execution mode handoff field to be required"
  exit 1
fi
replace_in_file "docs/features/feature-1/implementer-handoff.md" '- execution mode:' '- execution mode: multi-agent'
replace_in_file "docs/features/feature-1/tester-handoff.md" '- trivial-mode note: tester role remains active for this workflow mode' '- trivial-mode note:'
if bash scripts/gates/check-handoffs.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected tester trivial-mode note to be required"
  exit 1
fi
replace_in_file "docs/features/feature-1/tester-handoff.md" '- trivial-mode note:' '- trivial-mode note: tester role remains active for this workflow mode'
replace_in_file "docs/features/feature-1/reviewer-handoff.md" '- approval target: current final diff plus the current approval-target hash; reviewer `PASS` must match the final state that reaches gate completion' '- approval target:'
if bash scripts/gates/check-handoffs.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected reviewer approval target to be required"
  exit 1
fi
replace_in_file "docs/features/feature-1/reviewer-handoff.md" '- approval target:' '- approval target: current final diff plus the current approval-target hash; reviewer `PASS` must match the final state that reaches gate completion'
replace_in_file "docs/features/feature-1/security-handoff.md" '- approval binding: security receipt must record the current approval-target hash; any later approval-target change invalidates the security approval automatically' '- approval binding:'
if bash scripts/gates/check-handoffs.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected security approval binding to be required"
  exit 1
fi
replace_in_file "docs/features/feature-1/security-handoff.md" '- approval binding:' '- approval binding: security receipt must record the current approval-target hash; any later approval-target change invalidates the security approval automatically'
replace_in_file "docs/features/feature-1/plan.md" 'shell gate checks must not depend on app runtime modules' 'stale dependency constraint for digest failure'
if bash scripts/gates/check-handoffs.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected stale handoff digest to fail"
  exit 1
fi
if bash scripts/gates/check-test-matrix.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected stale test-matrix digest to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/plan.md" 'stale dependency constraint for digest failure' 'shell gate checks must not depend on app runtime modules'
bash scripts/sync-handoffs.sh feature-1 >/dev/null

replace_in_file "docs/features/feature-1/test-matrix.md" '`VERIFIED`' '`DRAFT`'
if bash scripts/gates/check-test-matrix.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected DRAFT test-matrix to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/test-matrix.md" '`DRAFT`' '`VERIFIED`'

replace_in_file "docs/features/feature-1/test-matrix.md" '| RQ-002 | covered | covered | covered | tests/example-module.test.mjs | VERIFIED |' '| RQ-002 | covered |  | covered | tests/example-module.test.mjs | VERIFIED |'
if bash scripts/gates/check-test-matrix.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected incomplete RQ row to fail"
  exit 1
fi
replace_in_file "docs/features/feature-1/test-matrix.md" '| RQ-002 | covered |  | covered | tests/example-module.test.mjs | VERIFIED |' '| RQ-002 | covered | covered | covered | tests/example-module.test.mjs | VERIFIED |'

rm "docs/features/feature-1/artifacts/roles/reviewer.json"
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected missing reviewer receipt to fail role-chain"
  exit 1
fi
write_role_receipt "reviewer" "review-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "reviewed diff and gate output" "security" "[]" "$approval_target_hash_value"

write_role_receipt "orchestrator" "orch-101" "docs/features/feature-1/run-log.md" "[RQ-001, RQ-002]" "[]" "PASS" "updated run-log and final summary" "planner" "src/example-module.mjs"
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected orchestrator touched-files outside policy to fail role-chain"
  exit 1
fi
write_role_receipt "orchestrator" "orch-101" "docs/features/feature-1/run-log.md" "[RQ-001, RQ-002]" "[]" "PASS" "updated run-log and final summary" "planner" "[]"

write_role_receipt "implementer" "impl-101" "src/example-module.mjs, tests/example-module.test.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "changed src/example-module.mjs and tests/example-module.test.mjs" "tester" "src/example-module.mjs, tests/example-module.test.mjs, src/not-in-plan.mjs"
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected implementer touched-files outside plan targets to fail role-chain"
  exit 1
fi
write_role_receipt "implementer" "impl-101" "src/example-module.mjs, tests/example-module.test.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "changed src/example-module.mjs and tests/example-module.test.mjs" "tester" "src/example-module.mjs, tests/example-module.test.mjs"

write_role_receipt "tester" "test-101" "docs/features/feature-1/test-matrix.md" "[RQ-001, RQ-002]" "[]" "PASS" "ran scripts/gates/check-tests.sh and updated test-matrix" "gate-checker" "docs/features/feature-1/test-matrix.md, src/example-module.mjs"
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected tester touched-files outside policy to fail role-chain"
  exit 1
fi
write_role_receipt "tester" "test-101" "docs/features/feature-1/test-matrix.md" "[RQ-001, RQ-002]" "[]" "PASS" "ran scripts/gates/check-tests.sh and updated test-matrix" "gate-checker" "docs/features/feature-1/test-matrix.md"

write_role_receipt "reviewer" "review-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "reviewed diff and gate output" "security" "src/example-module.mjs" "$approval_target_hash_value"
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected reviewer touched-files to fail role-chain"
  exit 1
fi
write_role_receipt "reviewer" "review-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "reviewed diff and gate output" "security" "[]" "$approval_target_hash_value"

replace_in_file "docs/features/feature-1/plan.md" 'shell gate checks must not depend on app runtime modules' 'shell gate checks must not depend on app runtime modules or stale approval targets'
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected stale reviewer/security approval hash to fail role-chain"
  exit 1
fi
replace_in_file "docs/features/feature-1/plan.md" 'shell gate checks must not depend on app runtime modules or stale approval targets' 'shell gate checks must not depend on app runtime modules'
approval_target_hash_value="$(
  source "$TMP_DIR/scripts/gates/_helpers.sh" feature-1
  approval_target_hash
)"
write_role_receipt "reviewer" "review-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "reviewed diff and gate output" "security" "[]" "$approval_target_hash_value"
write_role_receipt "security" "sec-101" "src/example-module.mjs" "[RQ-001, RQ-002]" "[]" "PASS" "checked validation and secrets paths" "complete" "[]" "$approval_target_hash_value"

replace_in_file "docs/features/feature-1/brief.md" '- mode: `full`' '- mode: `lite`'
replace_in_file "docs/features/feature-1/brief.md" '- rationale: reviewer and security stay required for the default gate fixture.' '- rationale: docs-only fixture stops after gate-checker.'
cat > "docs/features/feature-1/run-log.md" <<'EOF'
# Run Log

## Status
- feature-id: feature-1
- overall: `DONE`

## Dispatch Monitor
- current-role: gate-checker
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
- scope: docs/features/feature-1/plan.md, docs/features/feature-1/implementer-handoff.md, docs/features/feature-1/tester-handoff.md, docs/features/feature-1/reviewer-handoff.md, docs/features/feature-1/security-handoff.md, docs/features/feature-1/test-matrix.md
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: wrote plan.md, handoff files, and seeded test-matrix rows
- next_action: implementer

### implementer
- agent-id: impl-101
- scope: src/example-module.mjs, tests/example-module.test.mjs
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: changed src/example-module.mjs and tests/example-module.test.mjs
- next_action: tester

### tester
- agent-id: test-101
- scope: docs/features/feature-1/test-matrix.md
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
- next_action: complete
EOF
write_role_receipt "gate-checker" "gate-101" "scripts/gates/run.sh" "[RQ-001, RQ-002]" "[]" "PASS" "ran scripts/gates/run.sh feature-1" "complete" "[]"
rm "docs/features/feature-1/artifacts/roles/reviewer.json"
rm "docs/features/feature-1/artifacts/roles/security.json"
if ! bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected lite workflow without reviewer/security to pass role-chain"
  exit 1
fi

replace_in_file "docs/features/feature-1/brief.md" '- mode: `lite`' '- mode: `trivial`'
replace_in_file "docs/features/feature-1/brief.md" '- rationale: docs-only fixture stops after gate-checker.' '- rationale: tiny request skips tester and review while keeping planner-owned scope.'
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected trivial workflow with stale tester/reviewer/security outputs to fail role-chain"
  exit 1
fi
cat > "docs/features/feature-1/run-log.md" <<'EOF'
# Run Log

## Status
- feature-id: feature-1
- overall: `DONE`

## Dispatch Monitor
- current-role: gate-checker
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
- scope: docs/features/feature-1/plan.md, docs/features/feature-1/implementer-handoff.md, docs/features/feature-1/tester-handoff.md, docs/features/feature-1/reviewer-handoff.md, docs/features/feature-1/security-handoff.md, docs/features/feature-1/test-matrix.md
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: wrote plan.md, handoff files, and seeded test-matrix rows
- next_action: implementer

### implementer
- agent-id: impl-101
- scope: src/example-module.mjs, tests/example-module.test.mjs, docs/features/feature-1/test-matrix.md
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: changed src/example-module.mjs, tests/example-module.test.mjs, and finalized test-matrix
- next_action: gate-checker

### gate-checker
- agent-id: gate-101
- scope: scripts/gates/run.sh
- rq_covered: [RQ-001, RQ-002]
- rq_missing: []
- result: PASS
- evidence: ran scripts/gates/run.sh feature-1
- next_action: complete
EOF
write_role_receipt "implementer" "impl-101" "src/example-module.mjs, tests/example-module.test.mjs, docs/features/feature-1/test-matrix.md" "[RQ-001, RQ-002]" "[]" "PASS" "changed src/example-module.mjs, tests/example-module.test.mjs, and finalized test-matrix" "gate-checker" "src/example-module.mjs, tests/example-module.test.mjs, docs/features/feature-1/test-matrix.md"
rm "docs/features/feature-1/artifacts/roles/tester.json"
if ! bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected trivial workflow without tester/reviewer/security to pass role-chain"
  exit 1
fi

replace_in_file "docs/features/feature-1/run-log.md" '- last-progress: ran `scripts/gates/run.sh feature-1`' '- last-progress:'
if bash scripts/gates/check-role-chain.sh feature-1 >/dev/null 2>&1; then
  echo "[FAIL] expected missing dispatch progress to fail"
  exit 1
fi

echo "[PASS] gates smoke"
