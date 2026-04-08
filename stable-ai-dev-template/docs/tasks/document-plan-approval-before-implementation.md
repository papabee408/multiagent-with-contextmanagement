# Task: document-plan-approval-before-implementation

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-08 23:33:10Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-08 23:31:24Z
- approval-note: Approved in chat on 2026-04-08 America/Los_Angeles to document plan-first, approval-before-implementation behavior without adding hard guards.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one template-process clarification to make plan-first, approval-before-implementation behavior explicit without adding hard guards
- bundle-override-approved: no

## Goal
- Document more clearly that when a user gives a requirement, the operator should first create the task plan, get user approval, and only then implement.

## Non-goals
- Do not add new enforcement scripts or hard blocking guards.
- Do not change publish, review, or merge automation.

## Requirements
- RQ-001: Core operator guidance must explicitly say to draft the task plan and wait for user approval before implementation when a new requirement arrives.
- RQ-002: Workflow docs must show the plan and approval step as the default path before any implementation work.
- RQ-003: Smoke coverage must fail if the explicit plan-first approval guidance disappears from the live template.

## Implementation Plan
- Step 1: Update core operator guidance to make plan-first, approval-before-implementation language more explicit.
- Step 2: Update workflow docs so the requirement-to-plan-to-approval sequence is unambiguous.
- Step 3: Add smoke assertions that preserve the guidance in the live template and stable mirror.

## Architecture Notes
- intended module boundaries: keep operator behavior in `AGENTS.md`, workflow instructions in `README.md` and `docs/tasks/README.md`, and regression coverage in `tests/smoke.sh`
- dependency direction: operator docs define the rule and smoke assertions preserve it across template changes
- extraction/refactor triggers in touched files: if process guidance becomes too dense, split operator workflow rules into a dedicated process doc instead of overloading the top-level docs

## Target Files
- `AGENTS.md`
- `README.md`
- `docs/tasks/README.md`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/docs/tasks/README.md`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Changing task states, review fields, or CI behavior.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing workflow and approval sections instead of inventing a second approval system
- config/constants to centralize: keep the default sequence documented only in the core operator docs and mirrored template docs
- side effects to avoid: avoid implying automatic hard enforcement when this change is documentation-only

## Risk Controls
- sensitive areas touched: operator guidance and stable template parity
- extra checks before merge: rerun template sync and smoke after the wording update

## Acceptance
- The template explicitly says new requirements should go through task planning and user approval before implementation starts.
- Workflow docs make the sequence obvious enough that the default interpretation is plan first, implement second.
- Smoke assertions fail if the explicit wording disappears.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/document-plan-approval-before-implementation/verification.log
- verification-at-utc: 2026-04-08 23:32:54Z

## Review Status
- scope-review-status: pass
- scope-review-note: Scope stayed inside operator docs and smoke coverage for the plan-first clarification.
- scope-review-at-utc: 2026-04-08 23:33:05Z
- quality-review-status: pass
- quality-review-note: The wording makes plan-first approval explicit without introducing a new hard guard or changing workflow mechanics.
- quality-review-at-utc: 2026-04-08 23:33:07Z
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
- next action: If you want this published, create task/document-plan-approval-before-implementation from main and open one PR for the wording update.
- known risks: the wording must stay explicit without implying a new hard guard, and the stable template mirror must remain identical

## Completion
- summary: Documented that new requirements should go through task planning and explicit user approval before implementation begins.
- follow-up: If you want this published, create task/document-plan-approval-before-implementation from main and open one PR for the wording update.
