# Feature Plan

## Scope
- target files:
  - `scripts/sync-handoffs.sh`
  - `scripts/gates/check-test-matrix.sh`
  - `scripts/gates/check-scope.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-project-context.sh`
  - `scripts/gates/check-handoffs.sh`
  - `tests/sync-handoffs.test.sh`
  - `tests/gates.test.sh`
- out-of-scope files:
  - `scripts/gates/check-role-chain.sh`
  - `scripts/gates/check-tests.sh`
  - `README.md`
  - unrelated feature packets or context docs that are not required for the four trust-gap fixes

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2
- `RQ-003` -> Task 3
- `RQ-004` -> Task 4

## Architecture Notes
- target layer / owning module: keep policy checks in `scripts/gates/*.sh`, shared file classification/digest logic in `scripts/gates/_helpers.sh`, and generation behavior in `scripts/sync-handoffs.sh`
- dependency constraints / forbidden imports: stay shell-first with existing `node` fixture helpers only; do not move policy into dispatch/role wrapper scripts or broaden doc exceptions outside workflow-owned artifacts
- shared logic or component placement: reusable workflow-internal path checks and digest helpers belong in `scripts/gates/_helpers.sh`; per-gate assertions stay in each gate script

## Reuse and Config Plan
- existing abstractions to reuse: `changed_files`, `file_digest_or_missing`, `workflow_mode_from_brief`, and the existing shell fixture helpers in `tests/gates.test.sh`
- extraction candidates for shared component/helper/module: if path-classification logic is reused by multiple gates, extend `scripts/gates/_helpers.sh` instead of duplicating allowlist rules
- constants/config/env to centralize: workflow-internal path allowlists, matrix reset conditions, and handoff source-digest keys
- hardcoded values explicitly allowed: markdown section titles and gate labels that are already part of the packet format

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files:
  - `scripts/sync-handoffs.sh`
  - `scripts/gates/check-test-matrix.sh`
  - `tests/sync-handoffs.test.sh`
- change: make `test-matrix.md` drop out of `VERIFIED` whenever synced source digests change and cover that behavior with a focused sync regression
- done when: a previously verified matrix returns to `DRAFT` after `brief.md` or `plan.md` changes, and the test-matrix gate still accepts only concrete `VERIFIED` rows

### Task 2
- files:
  - `scripts/gates/check-scope.sh`
  - `scripts/gates/_helpers.sh`
  - `tests/gates.test.sh`
- change: replace the blanket doc exemption with a workflow-internal artifact exception so unrelated docs outside `plan.md` targets fail scope validation
- done when: current feature packet and closeout artifacts remain allowed, but unrelated docs like policy files fail the scope gate unless explicitly targeted

### Task 3
- files:
  - `scripts/gates/check-project-context.sh`
  - `tests/gates.test.sh`
- change: require non-empty content inside the mandatory project-context sections instead of accepting empty headings
- done when: effectively empty required sections fail `project-context`, while the real repo docs still pass

### Task 4
- files:
  - `scripts/gates/check-handoffs.sh`
  - `tests/gates.test.sh`
- change: validate `sync-script-sha` alongside the existing brief/plan/context/gates digests so generated handoffs become stale when the generator changes
- done when: stale generated handoffs fail after a `scripts/sync-handoffs.sh` change, and freshly synced handoffs still pass
