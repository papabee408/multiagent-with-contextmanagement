# Task: improve-followup-task-routing

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-08 17:58:27Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-08 17:53:24Z
- approval-note: Approved in chat on 2026-04-08 America/Los_Angeles to add faster follow-up task routing guidance to the template process.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one template-process improvement cluster to reduce wasted time when small follow-up requests arrive after or during a task
- bundle-override-approved: no

## Goal
- Add a fast follow-up routing rule so operators quickly decide whether to update the current task contract or open a new task before implementing small extra requests.

## Non-goals
- Do not redesign task state transitions, PR publishing, or merge automation.
- Do not add new runtime scripts when a documented decision rule is sufficient.

## Requirements
- RQ-001: Document a short decision rule that distinguishes between updating an in-progress task and opening a new task for a follow-up request.
- RQ-002: Make the rule explicit that `review` or `done` tasks must not absorb new follow-up requests; they require a new task.
- RQ-003: Tell operators which contract fields must be reconsidered before absorbing a follow-up into an in-progress task.
- RQ-004: Add lightweight regression coverage so the new follow-up guidance remains present in the live template.

## Implementation Plan
- Step 1: Update core operator docs with a dedicated follow-up request routing rule and a short default decision order.
- Step 2: Update task workflow docs and template improvement policy to align with the new routing rule.
- Step 3: Extend smoke assertions so the follow-up guidance stays present in the live template.

## Architecture Notes
- intended module boundaries: keep operator behavior rules in `AGENTS.md`, workflow usage notes in `README.md` and `docs/tasks/README.md`, and template-governance rules in `docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- dependency direction: durable policy docs define the routing rule and smoke assertions validate that the live template still exposes it
- extraction/refactor triggers in touched files: if intake guidance keeps growing, split routing and split/bundling policy into a dedicated process doc instead of expanding inline bullets further

## Target Files
- `AGENTS.md`
- `README.md`
- `docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- `docs/tasks/README.md`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- `stable-ai-dev-template/docs/tasks/README.md`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Changing the task schema or adding new receipt fields.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing intake and template-improvement policy docs instead of inventing a second process surface
- config/constants to centralize: centralize the follow-up routing rule in the core docs instead of scattering ad hoc advice through task comments
- side effects to avoid: avoid contradicting the one-request-one-task rule, and avoid advice that would encourage reopening completed tasks

## Risk Controls
- sensitive areas touched: operator process guidance and the mirrored stable template bundle
- extra checks before merge: rerun template sync and smoke to confirm the new guidance exists in both live and mirrored docs

## Acceptance
- The live template tells operators when a follow-up request may update an in-progress task and when it must open a new task.
- The rule explicitly says to revisit goal, target files, verification, and risk before absorbing a follow-up into an in-progress task.
- Smoke assertions fail if the follow-up routing guidance disappears from the live template.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/improve-followup-task-routing/verification.log
- verification-at-utc: 2026-04-08 17:56:57Z

## Review Status
- scope-review-status: pass
- scope-review-note: Scope matches the approved process change and stays within the documented operator surfaces.
- scope-review-at-utc: 2026-04-08 17:57:57Z
- quality-review-status: pass
- quality-review-note: The follow-up routing rule stays architecture-first, reuses existing process docs, and keeps regression coverage in smoke assertions.
- quality-review-at-utc: 2026-04-08 17:58:07Z
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
- next action: If you want this published, create task/improve-followup-task-routing from main and open one PR for the completed template diff.
- known risks: the guidance must stay short enough to be used quickly, and the mirrored stable template must remain identical

## Completion
- summary: Added a follow-up routing rule that forces an explicit task-vs-new-task decision before small extra requests are implemented, and mirrored the rule into the stable template with smoke coverage.
- follow-up: If you want this published, create task/improve-followup-task-routing from main and open one PR for the completed template diff.
