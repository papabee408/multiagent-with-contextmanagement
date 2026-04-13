# Task: clarify-review-routing-and-supersession

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-12 21:10:36Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-12 21:00:52Z
- approval-note: Approved in chat on 2026-04-12 America/Los_Angeles to patch review-stage routing and explicit task supersession handling.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one workflow stabilization change to distinguish review-feedback edits from true follow-up requests and to explicitly close replaced tasks
- bundle-override-approved: no

## Goal
- Clarify that review findings stay in the same task when the goal is unchanged, and add an explicit supersession flow so a replaced task is not left hanging when work moves to a new task.

## Non-goals
- Do not redesign PR publishing, merge automation, or CI merge-readiness rules for completed tasks.
- Do not relax the one-live-request-per-task contract for materially different follow-up requests.

## Requirements
- RQ-001: Document that review-stage fixes which preserve the approved goal and PR flow stay in the current task, even when the task state is `review`.
- RQ-002: Keep the rule that materially different follow-up requests in `review` or `done` must open a new task.
- RQ-003: Add a first-class workflow action that marks the replaced task as `superseded` when a new task takes over.
- RQ-004: Ensure the active task pointer moves to the replacement task during supersession so resume behavior stays coherent.
- RQ-005: Extend validation and smoke coverage so the new routing and supersession behavior remain enforced in both the live template and the mirrored stable bundle.

## Implementation Plan
- Step 1: Update operator-facing docs to distinguish review feedback from new follow-up requests and to describe the supersession flow.
- Step 2: Extend task validation and bootstrap behavior to support a `superseded` task state and explicit replacement linkage.
- Step 3: Add smoke coverage for the new guidance and the bootstrap supersession path, then rerun template checks.

## Architecture Notes
- intended module boundaries: keep durable policy in docs, keep task-state mutations in lifecycle scripts, and keep shared task-file mutations centralized in shell helpers when script logic would otherwise duplicate replacements
- dependency direction: operator docs define the routing policy, task scripts enforce state transitions, and smoke tests prove the mirrored template still behaves the same way
- extraction/refactor triggers in touched files: if bootstrap-task gains more task-closing variants beyond supersession, split the closeout logic into a dedicated lifecycle helper or command instead of growing inline flag handling further

## Target Files
- `AGENTS.md`
- `README.md`
- `docs/tasks/README.md`
- `docs/context/CURRENT.md`
- `docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- `scripts/_lib.sh`
- `scripts/bootstrap-task.sh`
- `scripts/check-task.sh`
- `scripts/init-project.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/docs/tasks/README.md`
- `stable-ai-dev-template/docs/context/CURRENT.md`
- `stable-ai-dev-template/docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- `stable-ai-dev-template/scripts/_lib.sh`
- `stable-ai-dev-template/scripts/bootstrap-task.sh`
- `stable-ai-dev-template/scripts/check-task.sh`
- `stable-ai-dev-template/scripts/init-project.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Reworking old completed task history, adding new PR metadata fields, or changing the merge gate to accept non-`done` tasks.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing task template fields, active-task pointer, and shell helper replacement utilities instead of inventing a second task metadata store
- config/constants to centralize: centralize supersession state handling and task-file field updates in shared shell helpers when multiple scripts depend on them
- side effects to avoid: avoid making superseded tasks publishable, avoid confusing review-finding fixes with new requirements, and avoid breaking existing task files that predate the new routing guidance

## Risk Controls
- sensitive areas touched: task-state validation, active-task resume behavior, mirrored stable template sync, and smoke workflow coverage
- extra checks before merge: rerun template sync and smoke so the root template and mirrored bundle stay aligned and the supersession path stays valid

## Acceptance
- The docs clearly say that review findings that keep the same goal stay in the current task, while materially new follow-up requests in `review` or `done` still require a new task.
- Operators can bootstrap a replacement task and explicitly mark the old task as `superseded` without leaving the old task ambiguous.
- Task validation accepts `superseded` tasks only when they carry a concrete redirect summary, and smoke coverage exercises the new flow.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/clarify-review-routing-and-supersession/verification.log
- verification-at-utc: 2026-04-12 21:10:14Z

## Review Status
- scope-review-status: pass
- scope-review-note: Scope matches the approved workflow surfaces and keeps the replacement-task handling inside docs, lifecycle scripts, and smoke coverage.
- scope-review-at-utc: 2026-04-12 21:10:25Z
- quality-review-status: pass
- quality-review-note: Quality review passed: review-loop guidance now matches the existing script behavior, superseded-task handling is explicit, and regression coverage protects both routing paths.
- quality-review-at-utc: 2026-04-12 21:10:25Z
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
- next action: If you want this published, create task/clarify-review-routing-and-supersession from main and open one PR for the completed template diff.
- known risks: existing task files must remain valid after the new state is introduced, and the replacement flow must not leave `.context/active_task` pointing at the superseded task

## Completion
- summary: Clarified that review-stage fixes stay in the same task, added explicit superseded-task handling to bootstrap-task, and covered the new routing with smoke tests.
- follow-up: If you want this published, create task/clarify-review-routing-and-supersession from main and open one PR for the completed template diff.
