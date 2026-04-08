# Feature Plan

## Scope
- target files:
  - `docs/agents/orchestrator.md`
  - `docs/context/GATES.md`
  - `docs/features/_template/run-log.md`
  - `scripts/dispatch-heartbeat.sh`
  - `scripts/gates/check-role-chain.sh`
  - `tests/dispatch-heartbeat.test.sh`
  - `tests/gates.test.sh`
  - `tests/run-log-ops.test.sh`
- out-of-scope files:
  - workflow routing files from stage 1 (`scripts/start-feature.sh`, `scripts/feature-packet.sh`)
  - reviewer/security role contracts beyond documentation references needed for dispatch monitor behavior

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 1
- `RQ-003` -> Task 2
- `RQ-004` -> Task 3

## Architecture Notes
- target layer / owning module: dispatch runtime behavior stays in `scripts/dispatch-heartbeat.sh`; gate interpretation stays in `scripts/gates/check-role-chain.sh`; docs/tests mirror that contract.
- dependency constraints / forbidden imports: keep shell entrypoints dependency-light; do not introduce a new persistent state file or nonstandard runtime dependencies.
- shared logic or component placement: timestamp parsing and guard transitions should stay local to the dispatch/gate scripts unless an existing helper already owns the behavior.

## Reuse and Config Plan
- existing abstractions to reuse: `monitor_field_value`, `update_monitor_field`, `workflow_roles_for_mode`, role receipt helpers, existing shell smoke fixture patterns
- extraction candidates for shared component/helper/module: keep deadline math and stale-state evaluation inside `dispatch-heartbeat.sh`; reuse receipt parsing already present in `check-role-chain.sh`
- constants/config/env to centralize: runtime guard thresholds (45s / 120s), valid dispatch statuses, required workflow role order
- hardcoded values explicitly allowed: run-log markdown section names and fixture timestamps used only inside deterministic tests

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files: `scripts/dispatch-heartbeat.sh`, `docs/features/_template/run-log.md`, `docs/agents/orchestrator.md`
- change: refresh idle deadlines from the latest actionable signal, add a stale-work `guard` command, and document how queue/start/progress/guard interact with the existing dispatch monitor fields
- done when: dispatch monitor outputs keep `queue` blank for start-only timestamps, refresh `interrupt-after-utc` after actionable updates, and allow stale active roles to transition to `AT_RISK` or `BLOCKED` through `guard`

### Task 2
- files: `scripts/gates/check-role-chain.sh`, `docs/context/GATES.md`
- change: enforce receipt timestamp order across required roles and tighten dispatch monitor timestamp consistency checks
- done when: role-chain fails for out-of-order receipts and contradictory monitor timelines while still passing valid `trivial`, `lite`, and `full` flows

### Task 3
- files: `tests/dispatch-heartbeat.test.sh`, `tests/run-log-ops.test.sh`, `tests/gates.test.sh`
- change: update smoke fixtures to cover guard transitions, refreshed deadlines, and required-role ordering
- done when: targeted shell tests and infra gate checks pass without adding new workflow overhead
