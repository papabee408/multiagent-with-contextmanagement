# Phase 5: Validator And Doc Dedupe

## Objective
- Reduce duplicate rule ownership in docs and validators without changing review semantics or task schema.

## Scope
- Dedupe CI/local validator ownership.
- Thin duplicate docs so they project the workflow rather than redefine it.
- Keep `review-scope.sh`, `scope-review-*`, and current freshness semantics unchanged in this phase.

## Planned Changes
- Make CI orchestrate existing validators instead of owning second copies of schema logic where possible.
- Reduce duplicated workflow text across `AGENTS.md`, `README.md`, `docs/tasks/README.md`, and `docs/context/RESUME_GUIDE.md`.
- Keep current scope-review and quality-review semantics intact so no freshness behavior changes occur here.

## Candidate Files
- `AGENTS.md`
- `README.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/RESUME_GUIDE.md`
- `docs/tasks/README.md`
- `scripts/_lib.sh`
- `scripts/check-task.sh`
- `scripts/ci/run-ai-gate.sh`
- `scripts/init-project.sh`
- `tests/smoke.sh`

## Non-goals
- Do not remove `review-scope.sh` in this phase.
- Do not delete review fields from the task template in this phase.
- Do not migrate freshness state in this phase.

## Validation
- CI and local validators no longer drift on duplicated rule blocks.
- Docs no longer restate the same rule differently.

## Risks
- Treating doc dedupe and schema simplification as the same change would make rollback noisy.

## Exit Criteria
- Validator ownership is clearer without changing behavior.
- Workflow docs are thinner and non-contradictory.
