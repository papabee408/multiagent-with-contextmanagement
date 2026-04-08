# Feature Brief

## Feature ID
- `feature-id`: template-core-trust-hardening

## Goal
- close the three template trust gaps from review so stale verification cannot look current, illegal feature re-entry cannot silently switch the active feature, and packet docs match the actual workflow rules

## Non-goals
- add new roles, new workflow modes, or multi-agent-only behavior
- weaken existing gate checks or reduce current regression coverage
- redesign packet structure beyond the targeted trust fixes

## Requirements (RQ)
- `RQ-001`: tester and gate-checker PASS results must bind to the current approval target so stale role receipts fail role-chain after relevant code or packet changes
- `RQ-002`: `scripts/start-feature.sh` must reject illegal mode/risk overrides for an existing feature before changing `.context/active_feature`
- `RQ-003`: user-facing template docs must describe mode-specific required packet files and approval-binding behavior consistently with the enforced gate policy
- `RQ-004`: regression tests must cover the stale-receipt binding and safe feature re-entry behaviors so the fixes stay stable

## Constraints
- preserve the existing `trivial|lite|full` workflow shape and `single|multi-agent` execution rules
- keep approval binding immune to closeout-only file churn such as `run-log.md`, role receipts, and context-log outputs
- prefer existing helper paths and receipt plumbing over introducing a second verification mechanism
- keep doc changes scoped to workflow/operator guidance that directly explains the enforced behavior

## Acceptance
- `scripts/gates/check-role-chain.sh` fails when tester or gate-checker PASS receipts were recorded against an older approval target, and still passes for current receipts
- `scripts/start-feature.sh` leaves the previous active feature untouched when an illegal re-entry override is rejected
- mode-specific packet file docs no longer instruct users to create handoff files that the gate would reject, and tester/gate-checker approval binding is documented where operators look first
- the targeted regression commands pass without breaking the current full gate flow

## Risk Signals
- auth-permissions: `no`
- payments-billing: `no`
- data-migration: `no`
- public-api: `no`
- infra-deploy: `no`
- secrets-sensitive-data: `no`
- blast-radius: `yes`
- note: switch one or more items to `yes` when the request touches that area deeply enough to justify `high-risk -> full`

## Risk Class
- class: `high-risk`
- rationale: change touches high-risk behavior and must start in the full workflow

## Workflow Mode
- mode: `full`
- rationale: higher-risk change keeps reviewer and security required from the start

## Execution Mode
- mode: `single`
- rationale: one lead agent owns the feature end-to-end; helper sub-agents stay optional and bounded

## Requirement Notes
- External dependencies: none beyond the existing shell/node test tooling and optional `gh` setup check
- Existing modules/components/constants to reuse: `approval_target_hash`, role receipt helpers, `scripts/record-role-result.sh`, `tests/gates.test.sh`, and `tests/start-feature.test.sh`
- Values/config that must not be hardcoded: approval-binding role rules, mode-specific packet file expectations, and active-feature safety checks should stay centralized in existing workflow helpers/docs instead of being duplicated ad hoc
