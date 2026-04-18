# Task: dedupe-ai-gate-checks

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-18 02:46:52Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-18 02:22:34Z
- approval-note: approved dedupe-first change for AI Gate with root and stable mirror parity

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one workflow maintenance cluster focused on removing duplicated verification runs inside AI Gate and its mirrored stable template flow
- bundle-override-approved: no

## Goal
- Remove duplicate verification executions inside AI Gate so the same command runs at most once per gate pass while preserving task verification plus repo-level supplemental checks.

## Non-goals
- Do not redesign the full task/approval/PR process in this task.
- Do not weaken scope checks, review requirements, or the required `AI Gate` status check.

## Requirements
- RQ-001: `scripts/ci/run-ai-gate.sh` must not execute the same verification command more than once in a single AI Gate run, even when it appears in both task verification and CI profile sections.
- RQ-001a: Task verification commands and CI-profile project checks must share one command-history mechanism so dedupe applies across both paths, not only within one section.
- RQ-002: Duplicate commands repeated across `PR Fast Checks`, `High-Risk Checks`, and `Full Project Checks` must also be skipped after the first execution in the same run.
- RQ-003: The gate output must clearly show when a duplicate command is skipped so behavior stays auditable.
- RQ-004: The root template and `stable-ai-dev-template/` mirror must keep the same behavior and documentation.
- RQ-005: Regression coverage must prove the dedupe path so later workflow changes do not reintroduce duplicate CI cost.
- RQ-006: This task removes only top-level duplicate command execution requested directly by AI Gate; nested overlap inside a command such as `tests/smoke.sh` rerunning `check-template-sync.sh` is deferred unless a narrow bug fix requires touching it.

## Implementation Plan
- Step 1: Add shared command-tracking for the full AI Gate run so task verification and CI-profile project checks register in one history and already-run commands are skipped instead of rerun.
- Step 2: Update the root and stable CI profile docs to describe project checks as supplemental work that should not duplicate task verification.
- Step 3: Extend smoke coverage to exercise a gate run with repeated commands and assert that each duplicate command executes only once.

## Architecture Notes
- intended module boundaries: keep orchestration in `scripts/ci/run-ai-gate.sh`, keep CI-profile command execution concerns in `scripts/ci/project-checks.sh`, keep durable workflow guidance in `docs/context/CI_PROFILE.md`, and keep end-to-end behavior checks in `tests/smoke.sh`
- dependency direction: the workflow entrypoint should delegate duplicate-skipping and profile execution to the CI helper module rather than embedding more command-selection logic inline
- extraction/refactor triggers in touched files: if `run-ai-gate.sh` starts carrying command-normalization or command-history logic beyond orchestration, extract that behavior into `scripts/ci/project-checks.sh` instead of growing the entry script further

## Target Files
- `docs/context/CI_PROFILE.md`
- `scripts/init-project.sh`
- `scripts/ci/project-checks.sh`
- `scripts/ci/run-ai-gate.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/docs/context/CI_PROFILE.md`
- `stable-ai-dev-template/scripts/init-project.sh`
- `stable-ai-dev-template/scripts/ci/project-checks.sh`
- `stable-ai-dev-template/scripts/ci/run-ai-gate.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Broader simplification of the full task lifecycle, approval flow, or PR publish/merge process.
- Refactoring nested verification internals such as changing what `tests/smoke.sh` itself invokes.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing task verification parser, CI profile sections, and mirrored stable template structure instead of inventing a second gate path
- config/constants to centralize: keep duplicate-detection rules and the single command-history handling inside the shared CI helper so task verification and all gate sections use the same logic
- side effects to avoid: avoid changing task resolution, scope enforcement, approval state handling, or introducing CI-only command lists that diverge between root and stable

## Risk Controls
- sensitive areas touched: AI Gate execution order, CI profile semantics, and root-versus-stable template parity
- extra checks before merge: rerun `bash scripts/check-template-sync.sh`, rerun `bash tests/smoke.sh`, and confirm the new smoke coverage proves duplicates are skipped with explicit log output

## Acceptance
- A task command that also appears in `PR Fast Checks` is executed once and skipped on repetition during the same AI Gate run.
- A repeated command across multiple CI profile sections is executed once and skipped on later repeats in the same AI Gate run.
- Task verification and project-check execution paths participate in the same dedupe behavior during one AI Gate run.
- AI Gate logs make skipped duplicates visible without hiding which section requested them.
- Nested duplication inside the body of a command remains unchanged and is explicitly left for a follow-up simplification task.
- Root and stable template files stay in sync and smoke coverage passes.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/dedupe-ai-gate-checks/verification.log
- verification-at-utc: 2026-04-18 02:45:45Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the approved root and stable mirror CI helper, gate runner, init-project seed list, and smoke coverage files
- scope-review-at-utc: 2026-04-18 02:46:23Z
- quality-review-status: pass
- quality-review-note: quality review passed: command-history state stays in the shared CI helper, run-ai-gate remains orchestration-only, init-project still accepts template seed history, and smoke proves verification/pr-fast/high-risk/full-project dedupe
- quality-review-at-utc: 2026-04-18 02:46:23Z
- reuse-review: pass
- hardcoding-review: pass
- tests-review: pass
- request-scope-review: pass
- architecture-review: pass
- risk-controls-review: n/a

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: auto-recover

## Session Resume
- current focus: task completed; ready to publish from the task branch
- next action: create or switch to task/dedupe-ai-gate-checks, stage the approved root and stable mirror files, commit, and publish the PR
- known risks: duplicate-skipping must not accidentally suppress distinct checks that only look similar, task verification and project checks must share one execution history, and nested duplication inside commands is intentionally deferred

## Completion
- summary: deduped repeated AI Gate commands by routing verification and CI-profile checks through one shared runner, preserved root/stable mirror parity, and added smoke coverage for cross-section skip behavior
- follow-up: create or switch to task/dedupe-ai-gate-checks, stage the approved root and stable mirror files, commit, and publish the PR
