# Task: upgrade-ai-gate-checkout-v5

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-04-08 18:22:27Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-08 18:20:28Z
- approval-note: Approved in chat on 2026-04-08 America/Los_Angeles to update AI Gate checkout from v4 to v5 only; harness changes are discussion-only.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one narrow workflow maintenance change to update the checkout action version in the AI Gate workflow
- bundle-override-approved: no

## Goal
- Update the root and stable AI Gate workflows from `actions/checkout@v4` to `actions/checkout@v5`.

## Non-goals
- Do not change harness, metrics, feedback, or template-health behavior.
- Do not modify CI gate logic beyond the checkout action version.

## Requirements
- RQ-001: `.github/workflows/ai-gate.yml` must use `actions/checkout@v5`.
- RQ-002: `stable-ai-dev-template/.github/workflows/ai-gate.yml` must stay identical to the root workflow and also use `actions/checkout@v5`.

## Implementation Plan
- Step 1: Update the root AI Gate workflow checkout action to `v5`.
- Step 2: Mirror the same change into the stable template workflow.
- Step 3: Rerun template-sync and smoke verification.

## Architecture Notes
- intended module boundaries: keep the action-version change confined to the workflow definition files only
- dependency direction: the root workflow remains the source of truth and the stable template mirror must stay byte-identical for synced paths
- extraction/refactor triggers in touched files: none for this narrow version bump

## Target Files
- `.github/workflows/ai-gate.yml`
- `stable-ai-dev-template/.github/workflows/ai-gate.yml`

## Out of Scope
- Documentation changes beyond runtime task bookkeeping.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing AI Gate workflow structure without altering job or step behavior
- config/constants to centralize: keep the action version only in the workflow files that already declare it
- side effects to avoid: avoid changing permissions, triggers, fetch depth, or CI script wiring

## Risk Controls
- sensitive areas touched: GitHub Actions workflow definitions mirrored into the stable template
- extra checks before merge: rerun template sync and smoke after the version bump

## Acceptance
- Both AI Gate workflow files use `actions/checkout@v5` and remain otherwise unchanged.
- Template sync and smoke checks pass after the update.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/upgrade-ai-gate-checkout-v5/verification.log
- verification-at-utc: 2026-04-08 18:21:34Z

## Review Status
- scope-review-status: pass
- scope-review-note: Scope stayed within the two mirrored workflow files only.
- scope-review-at-utc: 2026-04-08 18:21:49Z
- quality-review-status: pass
- quality-review-note: Narrow workflow-only version bump with no behavior changes beyond the checkout action version.
- quality-review-at-utc: 2026-04-08 18:22:19Z
- reuse-review: n/a
- hardcoding-review: n/a
- tests-review: n/a
- request-scope-review: n/a
- architecture-review: pass
- risk-controls-review: n/a

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: auto-recover

## Session Resume
- current focus: task completed; ready to publish from the task branch
- next action: If you want this published, create task/upgrade-ai-gate-checkout-v5 from main and open one PR for the workflow version bump.
- known risks: the stable workflow mirror must stay exactly in sync with the root workflow

## Completion
- summary: Updated the root and stable AI Gate workflows from actions/checkout@v4 to actions/checkout@v5.
- follow-up: If you want this published, create task/upgrade-ai-gate-checkout-v5 from main and open one PR for the workflow version bump.
