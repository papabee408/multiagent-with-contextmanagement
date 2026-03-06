# Feature Plan

## Scope
- target files:
  - `README.md`
  - `AGENTS.md`
  - `docs/agents/orchestrator.md`
  - `docs/agents/planner.md`
  - `docs/agents/tester.md`
  - `docs/context/GATES.md`
  - `docs/features/README.md`
  - `docs/features/_template/plan.md`
  - `docs/features/_template/run-log.md`
  - `docs/features/_template/test-matrix.md`
  - `scripts/dispatch-heartbeat.sh`
  - `scripts/gates/check-role-chain.sh`
  - `scripts/gates/check-test-matrix.sh`
  - `scripts/gates/check-tests.sh`
  - `scripts/gates/run.sh`
  - `tests/dispatch-heartbeat.test.sh`
  - `tests/gates.test.sh`
- out-of-scope files:
  - `builder/**`
  - production code outside template operations/docs

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2
- `RQ-003` -> Task 3

## Task Cards
### Task 1
- files:
  - `AGENTS.md`
  - `docs/agents/orchestrator.md`
  - `docs/agents/planner.md`
  - `docs/agents/tester.md`
  - `docs/context/GATES.md`
  - `docs/features/_template/plan.md`
  - `docs/features/_template/run-log.md`
  - `docs/features/_template/test-matrix.md`
- change:
  - Expose the full command flow, visibility rules, and test-matrix ownership in the template docs.
- done when:
  - Operators and role agents can see which command to use for queue/start/progress/gates without inferring it from scripts.

### Task 2
- files:
  - `scripts/gates/check-role-chain.sh`
  - `scripts/gates/check-test-matrix.sh`
  - `scripts/gates/check-tests.sh`
  - `scripts/gates/run.sh`
  - `tests/gates.test.sh`
- change:
  - Enforce `Dispatch Monitor` and `test-matrix` completeness in gates and cover the failure modes with regression tests.
- done when:
  - Missing monitor fields or unverified/incomplete test matrix rows cause gate failures locally and in CI.

### Task 3
- files:
  - `README.md`
  - `docs/features/README.md`
  - `scripts/dispatch-heartbeat.sh`
  - `tests/dispatch-heartbeat.test.sh`
- change:
  - Add an operator quick guide and a terminal-first heartbeat command for status visibility.
- done when:
  - An operator can inspect the active feature state with `scripts/dispatch-heartbeat.sh show` and find the common commands in one README.
