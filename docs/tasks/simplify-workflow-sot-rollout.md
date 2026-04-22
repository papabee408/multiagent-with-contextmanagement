# Task: simplify-workflow-sot-rollout

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: high-risk
- updated-at-utc: 2026-04-22 06:10:48Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-22 05:19:52Z
- approval-note: approved the full workflow SoT simplification rollout and requested a pre-PR readiness pass

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one workflow simplification cluster that removes split-brain process authorities while keeping CI, local status, publish, landing, and exported template behavior aligned.
- bundle-override-approved: no

## Goal
- Simplify the workflow so `docs/tasks/<task-id>.md` becomes the only canonical task-local record, helper/runtime files become optional evidence only, and the template source no longer carries a second committed mirror as another competing source of truth.

## Non-goals
- Do not change product feature behavior, loosen fail-closed CI rules, or add a second process path for the same task lifecycle.

## Requirements
- RQ-001: Workflow docs and validators must define non-overlapping ownership so task-local truth lives in the task file, CI defaults live in `docs/context/CI_PROFILE.md`, and helper surfaces no longer claim canonical authority.
- RQ-002: Local task selection must use explicit task id first and current task branch second, while `.context/active_task` and `docs/context/CURRENT.md` no longer act as authoritative workflow inputs.
- RQ-003: Verification, scope review, quality review, publish, land, status, and reporting flows must rely on tracked freshness and live Git/PR inspection instead of requiring `pr.env` or other local caches for correctness.
- RQ-004: The committed `stable-ai-dev-template/` mirror must be removed in favor of an export flow from the root source repo so the repository stops maintaining two writable template trees.
- RQ-005: The full smoke suite must pass after the SoT simplification rollout, including bootstrap, CI resolver, status, publish, land, freshness, and exported-bundle scenarios.

## Implementation Plan
- Step 1: Align ownership docs and local status/resume surfaces around the task file plus `status-task.sh`.
- Step 2: Narrow CI and local task resolution, remove persisted dashboard and active-task authority, and move publish/land freshness toward tracked task fields plus live PR lookup.
- Step 3: Replace the committed stable-template mirror with an export flow from the root source repo, then rerun full smoke coverage and close any rollout regressions.

## Architecture Notes
- intended module boundaries: lifecycle scripts under `scripts/` own task automation, context docs under `docs/context/` own durable repo guidance, task files under `docs/tasks/` own request-local contracts, and exported bundles are generated artifacts rather than parallel editable source trees.
- dependency direction: CI and local helper commands depend on the task contract plus shared library helpers, while export logic derives from the root repo source and must not become a second manually edited workflow surface.
- extraction/refactor triggers in touched files: extract dedicated helper functions when status, publish, or freshness logic starts duplicating task-resolution rules across scripts, and keep export-specific behavior isolated if template-source rules continue to grow.

## Target Files
- `.github/workflows/`
- `.gitignore`
- `.template-source-root`
- `AGENTS.md`
- `README.md`
- `docs/context/`
- `docs/plans/`
- `docs/tasks/README.md`
- `docs/tasks/_template.md`
- `scripts/`
- `stable-ai-dev-template/`
- `tests/smoke.sh`

## Out of Scope
- Product source code, unrelated feature-task rewrites, and GitHub repository settings outside the checked-in workflow/config files.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing task lifecycle scripts, shared shell helpers in `scripts/_lib.sh`, CI profile defaults, and smoke harness instead of inventing parallel validators or test runners.
- config/constants to centralize: keep workflow authority rules in `AGENTS.md`, Git/PR defaults in `docs/context/CI_PROFILE.md`, and task-local merge-readiness state in the task file rather than duplicating them in helper outputs.
- side effects to avoid: avoid reintroducing split-brain between tracked docs and `.context/`, avoid making PR correctness depend on local caches, and avoid leaving the root source repo plus exported bundle as two editable sources of truth.

## Risk Controls
- sensitive areas touched: CI task resolution, lifecycle state transitions, tracked freshness enforcement, local status/read-order policy, and template-source/export boundaries.
- extra checks before merge: rerun `bash tests/smoke.sh` after any workflow or task-doc drift, confirm the exported-bundle bootstrap scenarios still pass, and make sure no canonical path depends on `.context/active_task`, `.context/current.md`, or `pr.env`.

## Acceptance
- The rollout leaves one canonical task-local source of truth, helper/runtime files are optional only, the committed mirror is replaced by export flow, and the full smoke suite stays green with the new resolver/freshness/status behavior.

## Verification Commands
- `bash scripts/check-context.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/simplify-workflow-sot-rollout/verification.log
- verification-at-utc: 2026-04-22 06:10:01Z
- verification-fingerprint: b707e6e54bb9d6cc12dd74a102ca3564ee2a148c6c828c8aa5ce7e191f37cded

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the approved workflow, context, template-export, and smoke surfaces for the SoT simplification rollout
- scope-review-at-utc: 2026-04-22 06:10:08Z
- scope-review-fingerprint: b707e6e54bb9d6cc12dd74a102ca3564ee2a148c6c828c8aa5ce7e191f37cded
- quality-review-status: pass
- quality-review-note: quality review passed: task authority, CI resolution, freshness gates, local status policy, and template export flow stay within the intended workflow boundaries and remain covered by smoke
- quality-review-at-utc: 2026-04-22 06:10:24Z
- quality-review-fingerprint: b707e6e54bb9d6cc12dd74a102ca3564ee2a148c6c828c8aa5ce7e191f37cded
- reuse-review: pass
- hardcoding-review: pass
- tests-review: pass
- request-scope-review: pass
- architecture-review: pass
- risk-controls-review: pass

## Git / PR
- base-branch: pending
- branch-strategy: pending

## Completion
- summary: simplified the workflow SoT around the task file, removed local helper authority, hardened unpublished-versus-branch-gone status guidance, switched publish and status correctness to tracked state plus live lookup, and replaced the committed stable template mirror with export flow
- follow-up: create task/simplify-workflow-sot-rollout, commit the approved workflow changes, and open the PR
