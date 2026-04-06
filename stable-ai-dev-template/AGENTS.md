# Stable AI Dev Instructions

## Goal

Keep implementation quality consistent across context resets while changing only the files and behaviors approved by the current task.

## Read Order

1. `docs/context/CURRENT.md`
2. `.context/active_task`
3. `docs/tasks/<task-id>.md`
4. `docs/context/PROJECT.md`
5. `docs/context/ARCHITECTURE.md`
6. `docs/context/CONVENTIONS.md`
7. `docs/context/DECISIONS.md` only when the task or changed files depend on prior decisions

`docs/context/CI_PROFILE.md` is not part of the default read order. Read it only when the task touches CI, project setup, or verification command policy.
`docs/context/TEMPLATE_IMPROVEMENT_POLICY.md` is not part of the default read order. Read it only when the task changes this template itself or proposes a workflow improvement.

## Rules

- The active task file is the request-scoped source of truth.
- Any feature PR must change exactly one request-scoped `docs/tasks/*.md` file. Reuse the same task file for iterative work on that request until the PR merges.
- Every non-trivial request must follow `plan -> user approval -> implementation -> verification -> scope review -> quality review -> independent review -> completion`.
- The task defines both file scope and intent scope. Editing a target file does not authorize unrelated cleanup, refactors, renames, layout changes, or opportunistic rewrites inside that file.
- Change only `## Target Files` plus workflow-internal files:
  - `docs/tasks/<task-id>.md`
  - `docs/context/CURRENT.md`
  - `docs/context/DECISIONS.md`
  - `.context/active_task`
  - `.context/tasks/<task-id>/*`
- If a new file outside scope is required, update the task contract before editing it.
- If `unrelated changes allowed` is `no`, do not change behavior, naming, structure, styling, or formatting outside the user's request.
- If `incidental refactors allowed` is `no`, do not "clean up while here." Keep the implementation as narrow as possible.
- Prefer reuse and config centralization over new literals and copy-paste variants.
- Store platform/framework/CI setup in `docs/context/CI_PROFILE.md`, not in `AGENTS.md`.
- Do not change the template itself just because a metric or report suggests an improvement. First explain the proposed change simply and wait for explicit user approval.
- Use the task's `risk-level` to decide review depth:
  - `trivial`: mini-plan plus quick quality review
  - `standard`: full scope review plus standard quality review
  - `high-risk`: standard review plus explicit risk-controls review
- Do not edit implementation files while the task state is `planning` or `awaiting_approval`.
- After a PR is already merged, branch deletion, worktree removal, and local `main` sync are operational cleanup, not a tracked task.
- Do not create a new post-merge cleanup task just to record local git housekeeping.
- After merge, do not edit `docs/context/CURRENT.md` or `docs/tasks/*.md` for local cleanup notes.
- Before editing code, run:
  - `bash scripts/submit-task-plan.sh <task-id>`
  - wait for the user to approve the plan
  - `bash scripts/approve-task.sh <task-id> --by "<approver>" --note "<approval note>"`
  - `bash scripts/start-task.sh <task-id>`
- Before calling the task done, run:
  - `bash scripts/check-context.sh`
  - `bash scripts/check-task.sh <task-id>`
  - `bash scripts/check-scope.sh <task-id>`
  - `bash scripts/run-task-checks.sh <task-id>`
  - `bash scripts/review-scope.sh <task-id>`
  - `bash scripts/review-quality.sh <task-id> ...`
  - for `standard` and `high-risk`, ask a separate context-free sub-agent to do final code review, then record it with `bash scripts/review-independent.sh <task-id> --reviewer "<agent-id>" --summary "<findings or no-findings note>"`
- Finish with:
  - `bash scripts/complete-task.sh <task-id> "<summary>" "<next-step>"`

## Post-Merge Local Cleanup

Once the PR is merged, switch out of tracked task workflow for local housekeeping.

Allowed local-only cleanup:

- delete the remote branch if needed
- remove the local worktree if needed
- checkout `main`
- `git fetch --prune`
- `git pull`
- report unrelated pre-existing dirty files without trying to absorb them into a new task

Do not create `finalize-*` or `merge-cleanup-*` task files for this.

## Session Reset Rule

When starting a new session, do not scan the whole repository first. Use the read order above, then inspect only the files named by the active task and the current diff.
