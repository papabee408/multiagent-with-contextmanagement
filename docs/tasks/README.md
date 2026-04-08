# Task Contracts

Create one task file per live user request:

`docs/tasks/<task-id>.md`

## Core Rules

- One live request maps to one task file and one PR flow.
- Do not create separate PR tasks, merge tasks, or cleanup tasks for the same request.
- Default intake policy: one user-visible change cluster per task.
- If the request mixes independent features, recommend splitting before implementation.
- The task file defines both file scope and intent scope.

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

1. `bash scripts/bootstrap-task.sh <task-id>`
2. fill the task contract
3. `bash scripts/submit-task-plan.sh <task-id>`
4. wait for approval, then `bash scripts/approve-task.sh <task-id> --by "<approver>" --note "<approval note>"`
5. `bash scripts/start-task.sh <task-id>`
6. implement only inside `## Target Files`
7. `bash scripts/run-task-checks.sh <task-id>`
8. `bash scripts/review-scope.sh <task-id> --summary "<note>"`
9. `bash scripts/review-quality.sh <task-id> --summary "<note>" ...`
10. `bash scripts/complete-task.sh <task-id> "<summary>" "<next-step>"`
11. create or switch to the task branch, stage approved files explicitly, create the commit explicitly
12. `bash scripts/open-task-pr.sh <task-id>`
13. merge the PR manually after checks pass, for example `gh pr merge <pr-number> --squash --delete-branch`
14. restore `docs/context/CURRENT.md` to `HEAD`, sync local `main`, delete the local task branch, clear `.context/active_task`, then run `bash scripts/refresh-current.sh`
