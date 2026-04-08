# Task: simplify-pr-gate-flow

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-08 05:27:24Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-08 05:22:28Z
- approval-note: approved simplification for metadata recovery, shared diff logic, and trivial cleanup scope

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one workflow simplification cluster covering task resolution, PR metadata recovery, scope enforcement, and CI/local parity for small cleanup tasks
- bundle-override-approved: no

## Goal
- Simplify the task-driven git and CI flow so small doc and cleanup PRs do not fail on metadata bookkeeping while preserving one-request-one-task, deterministic verification, and latest-head merge discipline.

## Non-goals
- Do not remove task docs, deterministic verification commands, or target-files-based scope enforcement.
- Do not weaken merge gating into best-effort checks or reintroduce broad unrelated-change allowance.
- Do not break root versus `stable-ai-dev-template/` parity.

## Requirements
- RQ-001: Keep `1 request = 1 task doc`, deterministic verification, target-files-centered scope control, and merge only after the latest head is green.
- RQ-002: Treat PR metadata as auto-generated and auto-recoverable, not as a hard CI prerequisite.
- RQ-003: Resolve task identity in this order: explicit `CI_TASK_ID`, PR body `Task-ID`, branch name matching `task/<id>`, one changed live task file, then active task; only fail if all five fail.
- RQ-004: Remove tracked task-document fingerprint requirements; fingerprints may remain in runtime receipts, but CI must rely on actual diff plus verification re-execution instead of tracked summary fingerprints.
- RQ-005: Make local preflight and CI use the same diff calculation helpers so merge-ref versus local-ref differences do not create false failures.
- RQ-006: Add a trivial path for docs and delete-heavy cleanup work by supporting delete-only and prefix/glob scope allowances instead of requiring every deleted nested file to be enumerated one by one.
- RQ-007: Keep `open-task-pr` as the supported wrapper and make it repair existing PR metadata/body state when needed.

## Implementation Plan
- Step 1: Update the task contract and helper library so task resolution, diff calculation, scope matching, and runtime receipt freshness are shared between local scripts and CI.
- Step 2: Refactor publish and gate scripts to auto-recover PR metadata, stop depending on tracked fingerprints, and keep CI focused on task resolution, scope, and verification reruns.
- Step 3: Update task templates and live tracked task docs to remove tracked fingerprint fields from the supported surface.
- Step 4: Expand smoke coverage for branch-name and active-task fallback, missing metadata recovery, delete-only cleanup scope, and CI/local parity.

## Target Files
- `docs/tasks/_template.md`
- `docs/tasks/migrate-stable-ai-template.md`
- `docs/tasks/sync-stable-template-bundle.md`
- `.github/workflows/ai-gate.yml`
- `scripts/_lib.sh`
- `scripts/check-scope.sh`
- `scripts/check-task.sh`
- `scripts/ci/run-ai-gate.sh`
- `scripts/open-task-pr.sh`
- `scripts/refresh-current.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/docs/tasks/_template.md`
- `stable-ai-dev-template/docs/tasks/migrate-stable-ai-template.md`
- `stable-ai-dev-template/docs/tasks/sync-stable-template-bundle.md`
- `stable-ai-dev-template/.github/workflows/ai-gate.yml`
- `stable-ai-dev-template/scripts/_lib.sh`
- `stable-ai-dev-template/scripts/check-scope.sh`
- `stable-ai-dev-template/scripts/check-task.sh`
- `stable-ai-dev-template/scripts/ci/run-ai-gate.sh`
- `stable-ai-dev-template/scripts/open-task-pr.sh`
- `stable-ai-dev-template/scripts/refresh-current.sh`
- `stable-ai-dev-template/scripts/review-quality.sh`
- `stable-ai-dev-template/scripts/review-scope.sh`
- `stable-ai-dev-template/scripts/run-task-checks.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Redesigning the approval model or changing the merge method away from the current manual squash path.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: keep the task lifecycle scripts, runtime receipts under `.context/tasks/*`, and the mirrored stable bundle instead of creating a second workflow path
- config/constants to centralize: centralize task-id resolution, diff calculation, and scope matching inside shared shell helpers so local scripts and CI use the same rules
- side effects to avoid: avoid new hidden git state, avoid CI-only behavior branches, and avoid widening scope rules for non-trivial code changes

## Risk Controls
- sensitive areas touched: AI Gate task detection, scope enforcement, PR publish behavior, tracked task-doc format, and root versus bundle parity
- extra checks before merge: rerun root smoke, rerun nested smoke, and locally reproduce the CI gate path before publishing

## Acceptance
- A PR without manual metadata bookkeeping can still be published and pass CI when the branch, task doc, diff, and verification are otherwise valid.
- CI and local preflight identify the same task and changed-file set for the same branch diff.
- Tracked task docs and `CURRENT.md` no longer require fingerprint fields to stay green.
- Delete-heavy cleanup tasks can stay narrow without enumerating every deleted nested file as an exact target entry.

## Verification Commands
- `bash tests/smoke.sh`
- `bash stable-ai-dev-template/tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/simplify-pr-gate-flow/verification.log
- verification-at-utc: 2026-04-08 05:27:03Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the approved gate, task-doc, smoke, and mirror files while allowing the new prefix and delete-only rules
- scope-review-at-utc: 2026-04-08 05:27:12Z
- quality-review-status: pass
- quality-review-note: quality review passed: CI and local now share diff logic, PR metadata is auto-recovered, and smoke covers branch, active-task, and delete-only cleanup paths
- quality-review-at-utc: 2026-04-08 05:27:12Z
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
- next action: publish from task/simplify-pr-gate-flow and let the wrapper repair any existing PR metadata instead of relying on manual body edits
- known risks: smoke coverage is broad, task-doc format changes can ripple through tests, and root versus bundle parity must stay exact

## Completion
- summary: simplified AI Gate and PR publish flow so metadata is auto-recovered, CI and local share diff logic, and docs cleanup can use prefix or delete-only scope rules
- follow-up: publish from task/simplify-pr-gate-flow and let the wrapper repair any existing PR metadata instead of relying on manual body edits
