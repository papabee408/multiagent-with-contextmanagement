# Task: fix-land-task-restage-bug

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-22 06:53:39Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-22 06:50:24Z
- approval-note: Approved in chat on 2026-04-21 America/Los_Angeles to fix the land-task restaging bug after merge cleanup failed on an already-published delete scenario.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one workflow bugfix is needed so landing stops failing on already-published delete scenarios
- bundle-override-approved: no

## Goal
- Fix `land-task` so it can merge a publish-ready task even when the branch already contains approved committed deletions and there are no new local files to stage.

## Non-goals
- Do not redesign PR creation, required-check waiting, or the broader task state machine.

## Requirements
- RQ-001: `scripts/land-task.sh` must stage only current local worktree changes and must not try to `git add` files that exist only in already-committed task history.
- RQ-002: Shared helpers must expose a local-only changed-file view so landing and local status checks use the same definition of unstaged/staged/untracked work.
- RQ-003: Smoke coverage must reproduce an already-published tracked-file deletion and prove `land-task` merges that task cleanly.

## Implementation Plan
- Step 1: add a shared helper for local changed files and switch `land-task` staging to that helper.
- Step 2: align `status-task` local-change detection with the same helper so UI guidance stays consistent.
- Step 3: add a landing smoke regression for committed delete-only files and rerun full smoke verification.

## Architecture Notes
- intended module boundaries: keep change-file classification in `scripts/_lib.sh`, keep landing orchestration in `scripts/land-task.sh`, keep task status messaging in `scripts/status-task.sh`, and keep workflow regression coverage in `tests/smoke.sh`.
- dependency direction: `land-task.sh` and `status-task.sh` should consume shared helper output from `_lib.sh`, while smoke tests exercise the workflow from the CLI surface instead of reimplementing internals.
- extraction/refactor triggers in touched files: if another script needs a different notion of changed files, add a separate helper instead of broadening the local-only helper until it mixes staged-local and committed-history responsibilities again.

## Target Files
- `scripts/_lib.sh`
- `scripts/land-task.sh`
- `scripts/status-task.sh`
- `tests/smoke.sh`

## Out of Scope
- mirrored template changes, CI resolver policy changes, and unrelated publish-flow refactors remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse existing task changed-file helpers, task fingerprinting, land-task orchestration, and the fake GitHub smoke harness instead of adding one-off staging logic.
- config/constants to centralize: centralize local changed-file enumeration in `_lib.sh` so landing and status checks do not duplicate `git diff` command lists.
- side effects to avoid: avoid changing effective committed-diff behavior for scope/review checks, avoid reintroducing deleted tracked files into staging, and avoid widening the task beyond the four touched workflow files plus its task doc.

## Risk Controls
- sensitive areas touched: landing automation, local task status guidance, and workflow smoke coverage
- extra checks before merge: rerun `bash tests/smoke.sh` after the helper split and confirm the committed-delete landing regression passes inside the full suite.

## Acceptance
- `land-task` no longer fails with a `pathspec ... did not match any files` error when landing a published task whose diff already includes a tracked-file deletion, and full smoke coverage passes with the new regression scenario.

## Verification Commands
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/fix-land-task-restage-bug/verification.log
- verification-at-utc: 2026-04-22 06:52:55Z
- verification-fingerprint: 4b9f23861cf9cff255f38c0f9d48a688a6d40c59d0326d6d3463ec1bede468b9

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside landing helper logic, land-task staging, task status local-change detection, and smoke regression coverage
- scope-review-at-utc: 2026-04-22 06:53:01Z
- scope-review-fingerprint: 4b9f23861cf9cff255f38c0f9d48a688a6d40c59d0326d6d3463ec1bede468b9
- quality-review-status: pass
- quality-review-note: reviewed the helper split, local-only staging behavior, status-task consistency, and committed-delete smoke regression
- quality-review-at-utc: 2026-04-22 06:53:34Z
- quality-review-fingerprint: 4b9f23861cf9cff255f38c0f9d48a688a6d40c59d0326d6d3463ec1bede468b9
- reuse-review: pass
- hardcoding-review: pass
- tests-review: pass
- request-scope-review: pass
- architecture-review: pass
- risk-controls-review: n/a

## Git / PR
- base-branch: main
- branch-strategy: publish-late

## Completion
- summary: split local-only changed-file detection from committed task history, fixed land-task staging so published deletes are not restaged, aligned status-task, and added a committed-delete landing smoke regression
- follow-up: create or switch to task/fix-land-task-restage-bug, publish the approved diff, merge after checks pass, then sync local main and delete the task branch
