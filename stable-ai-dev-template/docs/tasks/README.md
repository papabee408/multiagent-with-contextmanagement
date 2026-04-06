# Task Contracts

Create one task file per user request:

`docs/tasks/<task-id>.md`

## Why One File

The task file is the only request-scoped contract. It answers:

- what approval was granted
- what is being built
- what must not change
- which files may be edited
- which kinds of edits are forbidden even inside those files
- which tests or checks must run
- what scope/quality review result was recorded
- what the next AI session should do next

## PR Mapping Rule

- A feature PR must change exactly one `docs/tasks/*.md` file.
- One user request may touch many product files, but the PR diff must still map to one request-scoped task file.
- Iterative work for the same request stays in the same task file until that PR merges.
- Create a follow-up task file only for a new request or for post-merge follow-up work, not for another pass on the same in-flight PR.
- If extra task-history files must be preserved, remove them from the feature PR and restore them only after merge in a separate cleanup task or commit.
- If AI Gate is blocked only because multiple task files changed, fix the PR with a repo-ops-only update that trims the diff back to one task file and does not change product files.

## Required Discipline

- set the risk level before asking for approval
- write an implementation plan before the task leaves `planning`
- keep target files explicit
- keep out-of-scope areas explicit
- keep scope guardrails explicit
- list concrete verification commands
- keep review status fields updated through the review scripts
- keep session resume fields current
- record approval before editing implementation files
- update the task before editing new files outside scope
- keep the PR diff to one changed `docs/tasks/*.md` file

## Workflow

1. `bash scripts/bootstrap-task.sh <task-id>`
2. fill `docs/tasks/<task-id>.md`
3. `bash scripts/submit-task-plan.sh <task-id>`
4. wait for user approval, then run `bash scripts/approve-task.sh <task-id> --by "<approver>" --note "<approval note>"`
5. `bash scripts/start-task.sh <task-id>`
6. implement only inside `## Target Files`
7. run `bash scripts/run-task-checks.sh <task-id>`
8. run `bash scripts/review-scope.sh <task-id>` and `bash scripts/review-quality.sh <task-id> ...`
9. refresh `CURRENT.md` whenever the next action changes
10. complete with `bash scripts/complete-task.sh <task-id> "<summary>" "<next-step>"`
