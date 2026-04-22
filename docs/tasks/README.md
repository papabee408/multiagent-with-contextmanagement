# Task Directory Guidance

Create one task file per live user request:

`docs/tasks/<task-id>.md`

## Directory Ownership

- `docs/tasks/<task-id>.md`: canonical request-local contract, task state, scope, verification commands, and review summaries
- `docs/tasks/_template.md`: task schema to start from when bootstrapping
- `docs/tasks/README.md`: directory guidance only
- `AGENTS.md`: live workflow rules and routing behavior
- `docs/context/CI_PROFILE.md`: repo defaults for CI and Git/PR behavior

## How To Use This Directory

- Bootstrap a new task with `bash scripts/bootstrap-task.sh <task-id>`.
- If the new task replaces the current one, use `bash scripts/bootstrap-task.sh <new-task-id> --supersedes <old-task-id> --reason "<why>"`.
- Fill the task contract before implementation.
- Validate the task contract with `bash scripts/check-task.sh <task-id>`.
- Validate scoped changes with `bash scripts/check-scope.sh <task-id>` once the diff exists.
- Use the task file as the request-local source of truth throughout the task lifecycle.
- Keep historical task files as records of the process that existed when they were executed.
- Treat those validator scripts as the schema authority instead of memorizing field combinations from docs.

## Common Commands

1. `bash scripts/bootstrap-task.sh <task-id>`
2. `bash scripts/submit-task-plan.sh <task-id>`
3. `bash scripts/approve-task.sh <task-id> --by "<approver>" --note "<approval note>"`
4. `bash scripts/start-task.sh <task-id>`
5. `bash scripts/run-task-checks.sh <task-id>`
6. `bash scripts/review-scope.sh <task-id> --summary "<note>"`
7. `bash scripts/review-quality.sh <task-id> --summary "<note>" --architecture pass ...`
8. `bash scripts/complete-task.sh <task-id> "<summary>" "<follow-up>"`
9. `bash scripts/land-task.sh <task-id>`

For the detailed behavioral rules behind those commands, use `AGENTS.md` instead of this file.
