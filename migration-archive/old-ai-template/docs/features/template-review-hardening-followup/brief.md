# Feature Brief

## Feature ID
- `feature-id`: template-review-hardening-followup

## Goal
- Harden the template's trust boundaries so stale verification, scope drift, empty project context, and stale handoff generators are rejected automatically.

## Non-goals
- Add new workflow modes, change role ownership, or refactor unrelated gate behavior outside the reviewed trust gaps.

## Requirements (RQ)
- `RQ-001`: When `brief.md` or `plan.md` changes after verification, `test-matrix.md` must reset to `DRAFT` until coverage is re-verified.
- `RQ-002`: Scope validation must keep allowing workflow-owned packet/closeout artifacts but fail unrelated docs or policy files that sit outside `plan.md` targets.
- `RQ-003`: `project-context` validation must fail required sections that exist structurally but are effectively empty.
- `RQ-004`: `handoffs` validation must include the `scripts/sync-handoffs.sh` generator digest so stale generated handoffs fail.

## Constraints
- Preserve existing workflow and gate behavior except where a change is required to close the four reviewed trust gaps.
- Keep fixes localized to existing gate/handoff helpers and regression tests; do not widen document exceptions or change role-chain semantics.

## Acceptance
- All four reviewed trust gaps are closed with focused regression coverage.
- `bash scripts/gates/check-tests.sh --full` still passes after the hardening changes.

## Risk Signals
- auth-permissions: `no`
- payments-billing: `no`
- data-migration: `no`
- public-api: `no`
- infra-deploy: `yes`
- secrets-sensitive-data: `no`
- blast-radius: `yes`
- note: switch one or more items to `yes` when the request touches that area deeply enough to justify `high-risk -> full`

## Risk Class
- class: `high-risk`
- rationale: core gate and workflow trust boundaries are changing, so stale approvals or invalid verification would affect the whole template

## Workflow Mode
- mode: `full`
- rationale: core workflow enforcement changes need tester, reviewer, and security validation from the start

## Execution Mode
- mode: `single`
- rationale: one lead agent should own this remediation end-to-end to minimize coordination risk while hardening core gates

## Requirement Notes
- External dependencies: local shell + node test tooling already used by the template; no new external services
- Existing modules/components/constants to reuse: `scripts/gates/_helpers.sh`, `scripts/sync-handoffs.sh`, and the existing shell smoke fixtures in `tests/*.test.sh`
- Values/config that must not be hardcoded: workflow-internal path allowlists, matrix status/source-digest fields, and required gate field names
