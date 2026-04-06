# Feature Brief

## Feature ID
- `feature-id`: review-followups-fix

## Goal
- Close the two workflow safety gaps from review so risk classification cannot be silently bypassed and dispatch monitor timestamps stay accurate across role handoffs.

## Non-goals
- Redesign the workflow model, add new roles, or change the existing risk-class defaults.

## Requirements (RQ)
- `RQ-001`: `brief` gate must fail when the required `## Risk Signals` checklist is missing or incomplete so `high-risk -> full` routing cannot be bypassed by deleting the section.
- `RQ-002`: dispatch monitor `started-at-utc` must reset to the current timestamp when a different active role starts, and the regression must be covered by shell smoke tests.

## Constraints
- Keep the fixes inside the existing shell workflow and reuse current parser/helpers instead of inventing a parallel validation path.

## Acceptance
- `bash scripts/gates/check-tests.sh --full` passes with new regression coverage for the missing risk-signals section and cross-role dispatch timestamp reset.

## Risk Signals
- auth-permissions: `no`
- payments-billing: `no`
- data-migration: `no`
- public-api: `no`
- infra-deploy: `no`
- secrets-sensitive-data: `no`
- blast-radius: `no`
- note: switch one or more items to `yes` when the request touches that area deeply enough to justify `high-risk -> full`

## Risk Class
- class: `standard`
- rationale: default product work keeps tester verification while avoiding reviewer/security overhead

## Workflow Mode
- mode: `lite`
- rationale: balanced default path with tester verification and no reviewer/security stage

## Execution Mode
- mode: `single`
- rationale: one lead agent owns the feature end-to-end; helper sub-agents stay optional and bounded

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: existing brief parsing helpers in `scripts/gates/_helpers.sh` and existing dispatch/gate smoke patterns in `tests/*.test.sh`
- Values/config that must not be hardcoded: required risk-signal keys and dispatch monitor timestamps must continue to come from existing helpers/runtime values
