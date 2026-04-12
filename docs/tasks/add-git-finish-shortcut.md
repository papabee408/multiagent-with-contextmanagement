# Task: add-git-finish-shortcut

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-12 20:14:55Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-12 20:06:22Z
- approval-note: Approved in chat on 2026-04-12 America/Los_Angeles to add the git finish landing script and trigger wording.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one workflow automation improvement for end-of-task git landing and its matching trigger phrase
- bundle-override-approved: no

## Goal
- Add a one-command git landing flow so a short request like `git 마무리해` can publish, merge, sync, and clean up the current task.

## Non-goals
- Do not change task planning, approval, verification, or quality review requirements before a task becomes publish-ready.

## Requirements
- RQ-001: Add `scripts/land-task.sh` to stage approved task-owned changes, commit them on the task branch, open or update the PR, wait for required checks, squash merge, sync local base, prune remote refs, delete the local task branch, clear `.context/active_task`, and refresh `.context/current.md`.
- RQ-002: Agent guidance must treat a short request like `git 마무리해` as authorization to run the landing script for the active task after the task is publish-ready.
- RQ-003: Operator docs must mention the landing script and its purpose.
- RQ-004: Smoke coverage must exercise the scripted landing flow with the fake GitHub CLI.
- RQ-005: Fresh copied repos must still treat this mirrored task file as template seed history so `init-project.sh` does not require `--force`.

## Implementation Plan
- Step 1: Add `scripts/land-task.sh` as a thin orchestrator over the existing task, PR, and git helpers.
- Step 2: Document the `git 마무리해` trigger and the landing script in the mirrored operator guidance.
- Step 3: Extend the fresh-repo seed allowlist for the new mirrored task file.
- Step 4: Add smoke coverage for the landing script and rerun template sync plus smoke verification.

## Architecture Notes
- intended module boundaries: keep landing orchestration in `scripts/land-task.sh`, keep reusable git/GitHub helpers in `scripts/_lib.sh`, and keep trigger wording in docs rather than product code.
- dependency direction: the landing script should reuse existing task state and PR helpers, query required checks from the CI profile and GitHub APIs, and avoid reimplementing approval or review logic.
- extraction/refactor triggers in touched files: move shared landing helpers into `_lib.sh` only if a second script needs the same behavior later.

## Target Files
- `AGENTS.md`
- `README.md`
- `scripts/land-task.sh`
- `scripts/init-project.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/scripts/land-task.sh`
- `stable-ai-dev-template/scripts/init-project.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- workflow state machine changes, CI job definitions, and unrelated publish or merge refactors remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse `open-task-pr.sh`, task state metadata, required-check resolution helpers in `_lib.sh`, and the existing fake `gh` smoke harness.
- config/constants to centralize: keep check polling knobs in `scripts/land-task.sh` via environment variables instead of scattering ad-hoc waits.
- side effects to avoid: avoid bypassing task completion gates, committing unrelated files, or leaving local and remote task branches behind after merge.

## Risk Controls
- sensitive areas touched: git/PR automation, active task runtime state, and template parity
- extra checks before merge: rerun `bash scripts/check-template-sync.sh` and `bash tests/smoke.sh`

## Acceptance
- A publish-ready task can be landed by running `bash scripts/land-task.sh` and the documented `git 마무리해` shortcut points the agent to that same flow.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/add-git-finish-shortcut/verification.log
- verification-at-utc: 2026-04-12 20:14:33Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the landing script, mirrored operator docs, seed allowlist, and smoke coverage
- scope-review-at-utc: 2026-04-12 20:14:40Z
- quality-review-status: pass
- quality-review-note: reviewed the landing orchestration, required-check polling, mirrored docs, and smoke coverage placement
- quality-review-at-utc: 2026-04-12 20:14:47Z
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
- next action: create or switch to task/add-git-finish-shortcut, commit the approved diff, publish the PR, merge after checks pass, then sync local main and delete the task branch
- known risks: the landing script must stay strict about task state and scope so it does not publish half-finished work

## Completion
- summary: added a land-task publish shortcut, wired the git 마무리해 trigger, and covered the flow in smoke
- follow-up: create or switch to task/add-git-finish-shortcut, commit the approved diff, publish the PR, merge after checks pass, then sync local main and delete the task branch
