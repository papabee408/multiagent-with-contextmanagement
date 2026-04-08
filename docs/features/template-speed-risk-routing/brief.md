# Feature Brief

## Feature ID
- `feature-id`: template-speed-risk-routing

## Goal
- Rebalance the template toward production-grade quality with a faster default path: new work should start in `lite + single`, escalate to `full` only for explicitly high-risk changes, and avoid generating role overhead that the chosen workflow will never use.

## Non-goals
- Rewrite the entire multi-agent model, remove RQ-based planning, or redesign test execution infrastructure beyond what is needed to support the faster default workflow contract.

## Requirements (RQ)
- `RQ-001`: New feature bootstrap must default to a risk-first workflow contract: `standard` work starts in `lite`, `high-risk` work starts in `full`, and execution stays `single` unless the user explicitly opts into `multi-agent`.
- `RQ-002`: Feature packets and handoff generation must only require workflow-relevant artifacts so `trivial`/`lite` work does not pay reviewer/security document overhead.
- `RQ-003`: Gate rules, role contracts, and regression tests must align with the new defaults so documentation, packet validation, and runtime checks all describe the same operating model.

## Constraints
- Preserve production-quality guardrails: RQ tracking, planner-owned scope, tester verification in `lite`, full reviewer/security approvals for `high-risk` work, and measurable gate enforcement.

## Acceptance
- A new packet can start with no explicit mode prompt, lands in `lite + single` for `standard` risk, promotes to `full` for `high-risk`, omits non-required handoff files per workflow mode, and the updated smoke/gate tests pass.

## Risk Class
- class: `standard`
- rationale: this change updates workflow defaults and gates but stays within the template's own shell/documentation boundary rather than altering product runtime behavior.

## Workflow Mode
- mode: `lite`
- rationale: default path favors speed with tester verification and no reviewer/security overhead

## Execution Mode
- mode: `single`
- rationale: one lead agent will carry the contract change end-to-end

## Requirement Notes
- External dependencies: existing shell helpers, gate scripts, and smoke tests only
- Existing modules/components/constants to reuse: `scripts/gates/_helpers.sh`, `scripts/sync-handoffs.sh`, `scripts/start-feature.sh`, and the existing packet/gate test fixtures
- Values/config that must not be hardcoded: workflow role chains, risk-to-workflow routing rules, optional handoff file policy, and execution mode defaults
