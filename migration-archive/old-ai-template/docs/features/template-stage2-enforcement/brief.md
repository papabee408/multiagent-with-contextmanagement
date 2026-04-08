# Feature Brief

## Feature ID
- `feature-id`: template-stage2-enforcement

## Goal
- Strengthen the template's runtime and role-order enforcement so the fast default path still catches stale execution and out-of-order role completion.

## Non-goals
- Do not add reviewer/security overhead back into the default `lite` workflow.
- Do not attempt to auto-detect semantic "clarification mode"; stage 2 only automates stale-progress enforcement from monitor timestamps.

## Requirements (RQ)
- `RQ-001`: `scripts/dispatch-heartbeat.sh` must refresh the runtime guard deadline from the latest actionable `start|progress|risk|done|blocked` signal so `interrupt-after-utc` tracks the current 120-second idle window instead of the original start time only.
- `RQ-002`: `scripts/dispatch-heartbeat.sh` must provide a guard command that reads the live dispatch monitor and auto-promotes stale active work to `AT_RISK` after 45 seconds idle and to `BLOCKED` after 120 seconds idle without faking a new progress timestamp.
- `RQ-003`: `scripts/gates/check-role-chain.sh` must enforce stronger execution integrity by validating required-role receipt timestamps in workflow order and by rejecting impossible dispatch monitor timestamp relationships.
- `RQ-004`: The run-log template, gate policy, orchestrator contract, and regression tests must describe and verify the stronger stage-2 enforcement contract without expanding the default `standard -> lite -> single` route.

## Constraints
- Keep the workflow lean: new enforcement should reuse the existing dispatch monitor fields instead of introducing a second heavy state log.
- Preserve backward-compatible operator behavior for `queue`, `start`, `progress`, `risk`, `blocked`, `done`, and `show`.
- Keep shell tests deterministic and avoid real-time sleeping in regression coverage.

## Acceptance
- `dispatch-heartbeat` updates `interrupt-after-utc` from the latest actionable output and exposes a `guard` command for stale-role checks.
- `role-chain` fails when role receipts are out of workflow order or when monitor timestamps are contradictory.
- Updated smoke tests cover the new guard behavior and ordering checks.
- Full infra checks still pass for the stage-2 feature packet.

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
- Existing modules/components/constants to reuse: existing dispatch monitor fields in `run-log.md`, role receipt `updated_at_utc`, shared gate helper shell functions
- Values/config that must not be hardcoded: workflow role order, runtime guard thresholds, run-log field names, allowed monitor states
