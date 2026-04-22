# Phase 8: Local Task Pointer Policy

## Objective
- Decide and implement the final role of `.context/active_task` without reintroducing split-brain.

## Scope
- Replace authoritative local task selection with an explicit final policy.
- Decide whether `.context/active_task` is:
  - removed, or
  - retained only as a non-authoritative convenience pointer

## Concrete Decision Gate
- The core SoT goal is satisfied once `.context/active_task` is no longer authoritative.
- Full deletion is allowed only if explicit task-id and/or branch-derived flows preserve operator usability.

## Planned Changes
- Define the final local task-selection rule:
  - explicit task id only, or
  - explicit task id plus branch-derived fallback
- Update `_lib.sh` and every no-arg lifecycle entrypoint that currently resolves through it.
- Demote `.context/active_task` in docs first.
- Remove writes and cleanup behavior only if the chosen replacement path is proven safe by tests and operator review.

## Candidate Files
- `AGENTS.md`
- `README.md`
- `docs/context/RESUME_GUIDE.md`
- `scripts/_lib.sh`
- `scripts/bootstrap-task.sh`
- `scripts/check-context.sh`
- `scripts/complete-task.sh`
- `scripts/land-task.sh`
- `scripts/open-task-pr.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `scripts/start-task.sh`
- `scripts/submit-task-plan.sh`
- `scripts/status-task.sh`
- `tests/smoke.sh`

## Non-goals
- Do not bundle telemetry/helper deletion into this phase.
- Do not re-broaden CI task resolution for convenience.

## Validation
- No canonical workflow decision depends on `.context/active_task`.
- If the file remains, docs mark it as optional and non-authoritative.
- If the file is removed, no-arg or branch-derived flows remain usable enough for day-to-day work.

## Risks
- Removing the pointer entirely may degrade local ergonomics even if the data model is cleaner.
- Keeping it without demoting it clearly would preserve the very ambiguity this rollout is trying to remove.

## Exit Criteria
- `.context/active_task` is either removed or explicitly non-authoritative.
- Local task selection has a documented, tested final policy.
