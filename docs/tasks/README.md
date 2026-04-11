# Task Contracts

Create one task file per live user request:

`docs/tasks/<task-id>.md`

If this repo was just copied from `stable-ai-dev-template/`, run `bash scripts/init-project.sh` first. The recommended first live task is `project-bootstrap`.
In Codex CLI, a plain request like "프로젝트 셋팅부터 하자" should trigger that bootstrap step before normal feature tasks begin.

## Core Rules

- One live request maps to one task file and one PR flow.
- Do not create separate PR tasks, merge tasks, or cleanup tasks for the same request.
- Default intake policy: one user-visible change cluster per task.
- If the request mixes independent features, recommend splitting before implementation.
- The task file defines both file scope and intent scope.

## Follow-up Routing

- If a follow-up arrives while the current task is `planning`, `awaiting_approval`, `approved`, or `in_progress`, decide whether it is still the same change cluster before editing code.
- Update the current task first when the follow-up keeps the same goal and PR flow, and revise `Goal`, `Target Files`, `Verification Commands`, and `risk-level` before implementation if the contract changes.
- If the task is already `review` or `done`, or the follow-up materially changes verification, risk, or review path, open a new task instead of widening the old one.
- When uncertain, choose a new task.

## Improvement Trigger Reporting

- If a workflow or template improvement trigger appears during delivery, finish the approved task first unless the user redirects.
- In the final update, report only `trigger`, `impact`, and `proposal`.
- Do not open or start an improvement task until the user explicitly decides to proceed.

## State Machine

`planning -> awaiting_approval -> approved -> in_progress -> review -> done`

Use scripts for state transitions. Do not hand-edit state fields directly.

## Branch Strategy

- Default: `publish-late`
- `publish-late` allows uncommitted work on the base branch.
- `publish-late` forbids local commits on the base branch.
- Before the first commit in `publish-late`, explicitly create or switch to the task branch.
- `open-task-pr` is publish-only. It does not create branches, stage files, or create commits.
- Use `early-branch` for long-running or checkpoint-heavy tasks.

## Workflow

Default rule before implementation: requirement -> task plan -> user approval -> `start-task` -> implementation.

1. `bash scripts/bootstrap-task.sh <task-id>`
2. fill the task contract
3. `bash scripts/submit-task-plan.sh <task-id>`
4. wait for approval, then `bash scripts/approve-task.sh <task-id> --by "<approver>" --note "<approval note>"`
5. `bash scripts/start-task.sh <task-id>`
6. implement only inside `## Target Files`
7. `bash scripts/run-task-checks.sh <task-id>`
8. `bash scripts/review-scope.sh <task-id> --summary "<note>"`
9. `bash scripts/review-quality.sh <task-id> --summary "<note>" --architecture pass ...`
10. `bash scripts/complete-task.sh <task-id> "<summary>" "<next-step>"`
11. create or switch to the task branch, stage approved files explicitly, create the commit explicitly
12. `bash scripts/open-task-pr.sh <task-id>`
13. merge the PR manually after checks pass, for example `gh pr merge <pr-number> --squash --delete-branch`
14. sync local `main`, delete the local task branch, clear `.context/active_task`, then run `bash scripts/refresh-current.sh` to rewrite `.context/current.md`
