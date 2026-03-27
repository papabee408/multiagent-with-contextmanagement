# Feature Plan

## Scope
- target files:
  - `AGENTS.md`
  - `README.md`
  - `docs/agents/README.md`
  - `docs/agents/orchestrator.md`
  - `docs/agents/planner.md`
  - `docs/agents/tester.md`
  - `docs/agents/gate-checker.md`
  - `docs/agents/implementer.md`
  - `docs/agents/reviewer.md`
  - `docs/agents/security.md`
  - `docs/context/CODEX_WORKFLOW.md`
  - `docs/context/GATES.md`
  - `docs/context/MULTI_AGENT_PROCESS.md`
  - `docs/features/README.md`
  - `docs/features/_template/brief.md`
  - `docs/features/_template/run-log.md`
  - `docs/features/_template/test-matrix.md`
  - `docs/features/_template/tester-handoff.md`
  - `docs/features/_template/reviewer-handoff.md`
  - `docs/features/_template/security-handoff.md`
  - `docs/features/workflow-speed-and-mode-upgrade/brief.md`
  - `docs/features/workflow-speed-and-mode-upgrade/plan.md`
  - `scripts/_git_change_helpers.sh`
  - `scripts/_role_receipt_helpers.sh`
  - `scripts/ci/detect-feature.sh`
  - `scripts/complete-feature.sh`
  - `scripts/feature-packet.sh`
  - `scripts/dispatch-heartbeat.sh`
  - `scripts/dispatch-role.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-brief.sh`
  - `scripts/gates/check-implementer-ready.sh`
  - `scripts/gates/check-handoffs.sh`
  - `scripts/gates/check-project-context.sh`
  - `scripts/gates/check-role-chain.sh`
  - `scripts/gates/check-tests.sh`
  - `scripts/gates/run.sh`
  - `scripts/promote-workflow.sh`
  - `scripts/record-role-result.sh`
  - `scripts/execution-mode.sh`
  - `scripts/stage-closeout.sh`
  - `scripts/sync-handoffs.sh`
  - `scripts/start-feature.sh`
  - `scripts/workflow-mode.sh`
  - `tests/check-tests-modes.test.sh`
  - `tests/dispatch-heartbeat.test.sh`
  - `tests/gate-cache.test.sh`
  - `tests/gates.test.sh`
  - `tests/implementer-subtasks.test.sh`
  - `tests/promote-workflow.test.sh`
  - `tests/start-feature.test.sh`
  - `tests/execution-mode.test.sh`
  - `tests/run-log-ops.test.sh`
  - `tests/stage-closeout.test.sh`
  - `tests/sync-handoffs.test.sh`
  - `tests/workflow-mode.test.sh`
- out-of-scope files:
  - unrelated product/app modules outside the workflow template
  - CI workflow definitions beyond command/documentation updates needed for the new gate modes

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2
- `RQ-003` -> Task 3
- `RQ-004` -> Task 4
- `RQ-005` -> Task 5
- `RQ-006` -> Task 6
- `RQ-007` -> Task 7
- `RQ-008` -> Task 6
- `RQ-009` -> Task 7

## Architecture Notes
- target layer / owning module: workflow-mode and execution-mode entrypoints stay under `scripts/`; gate policy stays under `scripts/gates/`; receipts remain under `docs/features/<feature-id>/artifacts/**`
- dependency constraints / forbidden imports: do not introduce non-shell runtime dependencies beyond existing `node` usage already required for tests/JSON helpers
- shared logic or component placement: centralize Git change-set parsing, approval-target hashing, and closeout staging candidate collection in shared helpers or thin wrappers rather than re-implementing per script

## Reuse and Config Plan
- existing abstractions to reuse: `scripts/gates/_helpers.sh`, `scripts/gates/_validation_cache.sh`, `scripts/_role_receipt_helpers.sh`, `scripts/_run_log_helpers.sh`, feature packet templates
- extraction candidates for shared component/helper/module: shared workflow/execution mode field parsing, approval-target hash helpers, local Git porcelain parsing
- constants/config/env to centralize: workflow mode names, execution mode names, fast/full gate labels, approval-target field names, protected file exclusions
- hardcoded values explicitly allowed: markdown headings and receipt field names required by the template/gate format

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files:
  - `AGENTS.md`
  - `README.md`
  - `docs/agents/README.md`
  - `docs/agents/orchestrator.md`
  - `docs/agents/planner.md`
  - `docs/agents/tester.md`
  - `docs/agents/gate-checker.md`
  - `docs/agents/reviewer.md`
  - `docs/agents/security.md`
  - `docs/context/CODEX_WORKFLOW.md`
  - `docs/context/GATES.md`
  - `docs/context/MULTI_AGENT_PROCESS.md`
  - `docs/features/README.md`
  - `docs/features/_template/brief.md`
  - `docs/features/_template/run-log.md`
  - `docs/features/_template/test-matrix.md`
  - `docs/features/_template/tester-handoff.md`
  - `docs/features/_template/reviewer-handoff.md`
  - `docs/features/_template/security-handoff.md`
  - `scripts/sync-handoffs.sh`
  - `scripts/execution-mode.sh`
- change:
  - Replace legacy mode guidance with user-owned workflow/execution mode selection and recommendation flow.
  - Introduce explicit `single|multi-agent` execution semantics in docs/templates while keeping `trivial`, `lite`, and `full` workflow semantics.
  - Keep generated handoffs aligned with planner-written `done when` guidance.
- done when:
  - Workflow/execution guidance is documented consistently and workflow templates mention `trivial`, `lite`, `full`, `single`, and `multi-agent` where applicable.

### Task 2
- files:
  - `scripts/feature-packet.sh`
  - `scripts/start-feature.sh`
  - `scripts/execution-mode.sh`
  - `scripts/workflow-mode.sh`
  - `scripts/promote-workflow.sh`
  - `scripts/_git_change_helpers.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-brief.sh`
  - `scripts/gates/check-project-context.sh`
  - `scripts/gates/check-handoffs.sh`
  - `scripts/gates/check-role-chain.sh`
  - `tests/workflow-mode.test.sh`
  - `tests/promote-workflow.test.sh`
  - `tests/start-feature.test.sh`
  - `tests/gates.test.sh`
- change:
  - Add locked workflow/execution mode bootstrap, keep a single feature packet through promotion, and update role-chain/state-machine checks accordingly.
- done when:
  - `workflow-mode.sh` accepts `trivial`, `execution-mode.sh` accepts `single|multi-agent`, `promote-workflow.sh` upgrades in place only, and gate tests cover the new route.

### Task 3
- files:
  - `scripts/_role_receipt_helpers.sh`
  - `scripts/record-role-result.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-role-chain.sh`
  - `docs/agents/reviewer.md`
  - `docs/agents/security.md`
  - `docs/features/_template/reviewer-handoff.md`
  - `docs/features/_template/security-handoff.md`
  - `tests/gates.test.sh`
- change:
  - Bind reviewer/security approval to a computed approval-target hash for the current final state and fail stale approvals automatically.
  - Exclude closeout-only operational files from approval-target invalidation.
- done when:
  - Reviewer/security receipts carry approval-target data, `check-role-chain.sh` rejects stale full-mode approvals, and closeout-only docs do not invalidate approvals.

### Task 4
- files:
  - `scripts/ci/detect-feature.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-tests.sh`
  - `scripts/gates/run.sh`
  - `tests/check-tests-modes.test.sh`
  - `tests/gate-cache.test.sh`
  - `tests/start-feature.test.sh`
  - `tests/implementer-subtasks.test.sh`
  - `tests/execution-mode.test.sh`
  - `tests/run-log-ops.test.sh`
  - `tests/sync-handoffs.test.sh`
  - `tests/gates.test.sh`
- change:
  - Centralize cheaper Git change-set collection, keep clean worktrees from falling back to the previous commit, and add `run.sh --fast` for local iteration while keeping the full gate authoritative.
- done when:
  - Local scripts reuse the shared change-set collector, clean worktrees report no current changes, `run.sh --fast` works, and regression tests cover the fast/full split.

### Task 5
- files:
  - `AGENTS.md`
  - `README.md`
  - `docs/agents/README.md`
  - `docs/agents/orchestrator.md`
  - `docs/agents/implementer.md`
  - `docs/context/GATES.md`
  - `docs/context/MULTI_AGENT_PROCESS.md`
  - `docs/features/README.md`
  - `scripts/dispatch-role.sh`
  - `scripts/dispatch-heartbeat.sh`
  - `scripts/gates/check-implementer-ready.sh`
  - `tests/run-log-ops.test.sh`
- change:
  - Block `implementer` dispatch until the current packet passes `brief`, `plan`, and `handoffs`.
  - Apply the same pre-implementation rule to `trivial`, `lite`, and `full`.
- done when:
  - `dispatch-role.sh` refuses `implementer` until `check-implementer-ready.sh` passes, and regression tests cover the blocked-then-allowed path.

### Task 6
- files:
  - `AGENTS.md`
  - `README.md`
  - `docs/agents/orchestrator.md`
  - `docs/context/GATES.md`
  - `docs/context/MULTI_AGENT_PROCESS.md`
  - `docs/features/README.md`
  - `docs/features/workflow-speed-and-mode-upgrade/brief.md`
  - `docs/features/workflow-speed-and-mode-upgrade/plan.md`
  - `scripts/complete-feature.sh`
  - `scripts/stage-closeout.sh`
  - `scripts/gates/check-tests.sh`
  - `tests/check-tests-modes.test.sh`
  - `tests/gate-cache.test.sh`
  - `tests/stage-closeout.test.sh`
- change:
  - Stage closeout-generated packet/context files automatically during `complete-feature.sh` so final commit, PR, and clean-tree checks absorb operational file churn instead of reporting false dirty state.
  - Limit closeout auto-staging to the active feature artifacts and the current completion session so unrelated context history does not get swept into the final commit.
  - Document that orchestrator should complete the feature before final git cleanliness checks and may opt out explicitly when needed.
- done when:
  - `complete-feature.sh` stages changed closeout files by default, unrelated session/context files remain unstaged, closeout staging is covered by regression tests, and operator docs explain the expected closeout-before-clean-tree order.

### Task 7
- files:
  - `docs/context/MULTI_AGENT_PROCESS.md`
  - `docs/features/README.md`
  - `docs/features/_template/run-log.md`
  - `scripts/dispatch-heartbeat.sh`
  - `scripts/gates/check-role-chain.sh`
  - `tests/dispatch-heartbeat.test.sh`
  - `tests/run-log-ops.test.sh`
  - `tests/gates.test.sh`
- change:
  - Keep `Dispatch Monitor` timestamps aligned with actual execution so `queue` stays visibly queued, while `start` or later execution signals establish `started-at-utc` and `interrupt-after-utc`.
- done when:
  - queued monitor states may leave start/interrupt timestamps blank, started states still require valid timestamps, and regression tests cover both contracts.
