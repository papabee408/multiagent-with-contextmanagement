# Resume Guide

This tracked file explains how to resume safely without treating local helper files as canonical workflow state.

## What To Trust

- `docs/tasks/<task-id>.md`: canonical tracked task contract, task state, scope, and verification/review summaries
- `AGENTS.md`: canonical workflow behavior and routing rules
- `docs/context/CI_PROFILE.md`: repo CI defaults and check inventory
- `.context/tasks/<task-id>/*`: runtime evidence and optional local cache output; not required for correctness

## Fast Resume Order

1. explicit task id, or the current task branch when it maps cleanly to a live task
2. `docs/tasks/<task-id>.md`
3. `bash scripts/status-task.sh [task-id]`
4. `docs/context/RESUME_GUIDE.md`
5. `docs/context/PROJECT.md`
6. `docs/context/ARCHITECTURE.md`
7. `docs/context/CONVENTIONS.md`
8. `docs/context/CI_PROFILE.md` only if the task touches git, PR, merge, verification policy, or CI
9. `docs/context/DECISIONS.md` only if the task or diff depends on prior decisions

## When Surfaces Conflict

- Trust the task file for tracked task-local truth.
- Trust `AGENTS.md` for workflow behavior.
- Trust `docs/context/CI_PROFILE.md` for repo CI defaults.
- Ignore `.context/active_task` if it still exists from an older workflow.

## Runtime Notes

- Run `bash scripts/status-task.sh [task-id]` when you want a local status summary.
- `bash scripts/refresh-current.sh [task-id]` is a compatibility alias for `status-task.sh`; it does not write a persisted dashboard file.
- Local task selection uses `explicit task id` first, then the current task branch.
- After task-file or scoped-code edits, rerun `bash scripts/check-task.sh <task-id>` and `bash scripts/check-scope.sh <task-id>` instead of inferring merge-readiness by hand.
- Start a brand new task from a clean worktree.
- If a replacement task takes over, use `bash scripts/bootstrap-task.sh <new-task-id> --supersedes <old-task-id> --reason "<why>"`.
- Do not commit `.context/` runtime files.
