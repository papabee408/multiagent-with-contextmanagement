# Task: separate-current-snapshot-runtime-state

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-10 21:05:08Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-10 20:54:50Z
- approval-note: Approved in chat on 2026-04-10 America/Los_Angeles to separate tracked context guidance from runtime snapshot state and eliminate dirty worktree churn after refresh and merge flows.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one workflow change cluster to separate tracked context policy from untracked runtime snapshot state so merge and refresh flows can return to a clean worktree
- bundle-override-approved: no

## Goal
- Move the mutable current snapshot out of tracked `docs/context/CURRENT.md` into gitignored runtime state so normal task, PR, and merge flows stop re-dirtying the repository.

## Non-goals
- Do not redesign the task state machine, PR metadata policy, or review receipt model.
- Do not add a second task-tracking system beyond the existing `.context/` runtime state.

## Requirements
- RQ-001: `scripts/refresh-current.sh` must write the mutable current snapshot only under `.context/` and must stop rewriting tracked `docs/context/CURRENT.md`.
- RQ-002: Runtime snapshot readers and workflow rules must consume the `.context/` snapshot instead of relying on tracked `docs/context/CURRENT.md`.
- RQ-003: `docs/context/CURRENT.md` and the mirrored stable-template copy must become stable documentation or entry guidance rather than task-local runtime state.
- RQ-004: Scope, CI, publish-cleanliness, and smoke coverage must stop treating tracked `docs/context/CURRENT.md` as a routine runtime byproduct.
- RQ-005: Operator docs must explain the new resume order clearly enough that a fresh session reads the runtime snapshot from `.context/` without ambiguity.

## Implementation Plan
- Step 1: Refactor the current snapshot boundary so refresh/write logic and active-task fallback read and write an untracked `.context` snapshot file instead of tracked `docs/context/CURRENT.md`.
- Step 2: Update workflow rules, read-order docs, and the tracked `docs/context/CURRENT.md` file so policy docs stay stable while runtime resume data lives under `.context/`.
- Step 3: Remove the special-case clean/scope/CI allowances for tracked `docs/context/CURRENT.md` and update smoke coverage plus the stable template mirror to enforce the new behavior.

## Architecture Notes
- intended module boundaries: keep durable workflow policy in tracked docs (`AGENTS.md`, `README.md`, `docs/context/*.md`), keep runtime snapshot generation and lookup in shell infrastructure under `scripts/`, and keep regression coverage in `tests/smoke.sh`
- dependency direction: operator docs describe the runtime snapshot location, lifecycle scripts and helpers implement it under `.context/`, and smoke tests verify both the live template and stable mirror stay aligned
- extraction/refactor triggers in touched files: if `scripts/_lib.sh` or `scripts/refresh-current.sh` needs more than one snapshot format or path concern, extract narrow helper functions for current-snapshot path resolution and rendering instead of growing more mixed logic

## Target Files
- `AGENTS.md`
- `README.md`
- `docs/context/`
- `docs/tasks/README.md`
- `scripts/_lib.sh`
- `scripts/bootstrap-task.sh`
- `scripts/check-scope.sh`
- `scripts/ci/run-ai-gate.sh`
- `scripts/refresh-current.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/docs/context/`
- `stable-ai-dev-template/docs/tasks/README.md`
- `stable-ai-dev-template/scripts/_lib.sh`
- `stable-ai-dev-template/scripts/bootstrap-task.sh`
- `stable-ai-dev-template/scripts/check-scope.sh`
- `stable-ai-dev-template/scripts/ci/run-ai-gate.sh`
- `stable-ai-dev-template/scripts/refresh-current.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Changing unrelated task contract fields, archived multi-agent packets, or GitHub workflow semantics beyond what is needed for the snapshot-path split.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing `.context/active_task` and `.context/tasks/<task-id>/*` runtime model instead of inventing another state directory or storage mechanism
- config/constants to centralize: centralize the runtime current-snapshot path and any tracked-current-doc path references in shared shell helpers rather than scattering string literals across scripts
- side effects to avoid: avoid leaving tracked docs with hidden runtime coupling, avoid keeping clean-worktree exceptions for `docs/context/CURRENT.md`, and avoid breaking the stable-template mirror

## Risk Controls
- sensitive areas touched: resume workflow docs, scope enforcement, clean-worktree rules, CI task resolution, and root-versus-stable template parity
- extra checks before merge: rerun template sync validation and full smoke coverage after the snapshot split and confirm merge cleanup no longer requires restoring tracked `docs/context/CURRENT.md`

## Acceptance
- Normal task state transitions and post-merge cleanup can refresh the current snapshot without producing tracked diffs from runtime-only state.
- The repository reads active task and current snapshot data from `.context/` runtime files, while tracked `docs/context/CURRENT.md` remains stable across ordinary task execution.
- Scope checks, CI allowances, and smoke tests reflect the new boundary and no longer rely on committing runtime snapshot changes.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/separate-current-snapshot-runtime-state/verification.log
- verification-at-utc: 2026-04-10 21:04:54Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the approved docs, shell workflow scripts, smoke coverage, and stable mirror files for the runtime snapshot split
- scope-review-at-utc: 2026-04-10 21:04:58Z
- quality-review-status: pass
- quality-review-note: Runtime snapshot generation now stays in scripts plus gitignored .context state, while tracked docs only carry stable resume guidance; scope, clean-worktree rules, CI allowances, and smoke coverage all align with that boundary.
- quality-review-at-utc: 2026-04-10 21:05:03Z
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
- next action: create or switch to task/separate-current-snapshot-runtime-state, commit the approved diff, and publish the PR
- known risks: read-order docs, clean-worktree exceptions, and smoke expectations currently assume tracked `docs/context/CURRENT.md` is mutable, so a partial migration would leave contradictory workflow behavior

## Completion
- summary: Separated mutable current snapshot state from tracked context guidance so refresh and merge flows stop re-dirtying the repository.
- follow-up: create or switch to task/separate-current-snapshot-runtime-state, commit the approved diff, and publish the PR
