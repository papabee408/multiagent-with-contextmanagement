# Feature Plan

## Scope
- target files:
  - `scripts/_role_receipt_helpers.sh`
  - `scripts/_run_log_helpers.sh`
  - `scripts/record-role-result.sh`
  - `scripts/gates/check-role-chain.sh`
  - `scripts/start-feature.sh`
  - `scripts/sync-handoffs.sh`
  - `README.md`
  - `docs/context/GATES.md`
  - `docs/features/README.md`
  - `docs/agents/tester.md`
  - `docs/agents/gate-checker.md`
  - `tests/gates.test.sh`
  - `tests/run-log-ops.test.sh`
  - `tests/start-feature.test.sh`
- out-of-scope files:
  - `scripts/gates/run.sh`
  - `scripts/gates/check-tests.sh`
  - reviewer/security role contracts unless approval-binding wording requires a small consistency touch
  - unrelated feature packets or historical session logs

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2
- `RQ-003` -> Task 3
- `RQ-004` -> Task 4

## Architecture Notes
- target layer / owning module: keep receipt generation in `scripts/_role_receipt_helpers.sh` and `scripts/record-role-result.sh`, stale-verification enforcement in `scripts/gates/check-role-chain.sh`, bootstrap safety in `scripts/start-feature.sh`, and operator guidance in the existing workflow docs
- dependency constraints / forbidden imports: stay inside the existing shell-first workflow; do not add new runtime dependencies or split trust checks across unrelated scripts
- shared logic or component placement: role approval-binding rules should live in shared receipt/gate helpers, while mode-specific operator wording stays in `README.md`, `docs/context/GATES.md`, and role contracts

## Reuse and Config Plan
- existing abstractions to reuse: `approval_target_hash`, `approval_target_files`, `write_role_receipt`, and the existing shell fixture helpers in `tests/gates.test.sh`
- extraction candidates for shared component/helper/module: if multiple scripts need to know which roles require approval binding or run-log section boundaries, keep that rule in one helper path rather than duplicating conditionals
- constants/config/env to centralize: approval-binding role lists and mode-specific packet file expectations
- hardcoded values explicitly allowed: current role names, markdown section titles, and gate labels that are already part of the packet format

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files:
  - `scripts/_role_receipt_helpers.sh`
  - `scripts/_run_log_helpers.sh`
  - `scripts/record-role-result.sh`
  - `scripts/gates/check-role-chain.sh`
  - `scripts/sync-handoffs.sh`
  - `docs/context/GATES.md`
  - `docs/agents/tester.md`
  - `docs/agents/gate-checker.md`
- change: bind tester and gate-checker PASS receipts to the same current approval-target model already used for reviewer/security, and expose the requirement in the distilled/operator docs
- done when: stale tester or gate-checker PASS receipts fail role-chain after relevant file changes, current receipts still pass, tester guidance explains the binding, and the last run-log role section can still be replaced without dropping trailing notes

### Task 2
- files:
  - `scripts/start-feature.sh`
  - `tests/start-feature.test.sh`
- change: validate illegal existing-feature override requests before switching the active feature, then cover the failure path with a focused bootstrap regression
- done when: rejected re-entry override commands keep `.context/active_feature` unchanged and existing happy-path bootstrap behavior still passes

### Task 3
- files:
  - `README.md`
  - `docs/context/GATES.md`
  - `docs/features/README.md`
  - `docs/agents/tester.md`
  - `docs/agents/gate-checker.md`
- change: align required-packet-file and approval-binding wording across the operator docs with the actual enforced gate behavior
- done when: docs describe mode-specific handoff requirements accurately and no operator-facing guide tells the user to create files that `check-handoffs.sh` would reject

### Task 4
- files:
  - `tests/gates.test.sh`
  - `tests/run-log-ops.test.sh`
  - `tests/start-feature.test.sh`
- change: extend regression fixtures to prove stale receipt rejection, safe active-feature preservation, and last-section run-log replacement without weakening current smoke coverage
- done when: the targeted shell tests cover normal/error paths for the new trust checks and continue to pass under the existing full regression command
