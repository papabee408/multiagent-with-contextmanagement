# Phase 4: Persisted Dashboard Removal

## Objective
- Remove `.context/current.md` as persisted workflow state after the replacement status command is proven.

## Scope
- Stop all lifecycle scripts from writing `.context/current.md`.
- Remove dashboard-specific scope allowances and smoke expectations.
- Keep a compatibility wrapper only if needed to avoid breaking existing operator muscle memory.

## Concrete Migration Rule
- `scripts/status-task.sh` is the supported status surface.
- `scripts/refresh-current.sh` may remain temporarily as a thin compatibility wrapper that calls `status-task.sh`, but it must not write `.context/current.md`.

## Planned Changes
- Remove `.context/current.md` writes from all lifecycle and bootstrap flows.
- Update all former refresh callers, including approval / start / review / complete / publish flows.
- Remove `.context/current.md` from workflow-internal file exceptions and scope allowances.
- Rewrite smoke scenarios that assert dashboard contents after bootstrap, completion, fallback, and merge cleanup.

## Candidate Files
- `AGENTS.md`
- `README.md`
- `docs/context/RESUME_GUIDE.md`
- `scripts/_lib.sh`
- `scripts/approve-task.sh`
- `scripts/bootstrap-task.sh`
- `scripts/check-scope.sh`
- `scripts/complete-task.sh`
- `scripts/init-project.sh`
- `scripts/land-task.sh`
- `scripts/open-task-pr.sh`
- `scripts/refresh-current.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `scripts/start-task.sh`
- `scripts/submit-task-plan.sh`
- `scripts/status-task.sh`
- `tests/smoke.sh`

## Non-goals
- Do not remove `.context/active_task` in this phase.
- Do not change review/freshness semantics in this phase.

## Validation
- No script writes `.context/current.md`.
- Scope validation no longer blesses `.context/current.md`.
- Smoke tests no longer assert on persisted dashboard file contents.

## Risks
- Removing writes before the status command is actually adopted will regress operator UX.

## Exit Criteria
- `.context/current.md` is no longer a runtime artifact.
- `refresh-current.sh`, if it still exists, no longer writes persisted state.
- Operators can inspect status without relying on a generated file.
