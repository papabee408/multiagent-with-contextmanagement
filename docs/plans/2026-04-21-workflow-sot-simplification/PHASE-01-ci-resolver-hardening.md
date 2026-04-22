# Phase 1: CI Resolver Hardening

## Objective
- Remove CI dependence on local runtime task state while keeping a compatibility-safe task-resolution path.

## Scope
- Stop CI from reading or writing `.context/active_task`.
- Define and implement one concrete CI resolver order.
- Keep compatibility resolvers that are already part of the live workflow until the event matrix proves they can be retired.

## Concrete Migration Rule
- Temporary CI resolver order for this phase:
  - explicit `CI_TASK_ID`
  - PR body `Task-ID`
  - branch-derived task id
  - exactly one changed live task file
  - fail otherwise
- `.context/active_task` is removed from CI resolution in this phase.

## Planned Changes
- Update `.github/workflows/ai-gate.yml` so the workflow contract for task identity is explicit and documented.
- Update `scripts/ci/run-ai-gate.sh` to follow the temporary resolver order above.
- Stop `run-ai-gate.sh` from writing `.context/active_task`.
- Keep `open-task-pr.sh` PR metadata generation as a supported compatibility path during this phase.
- Add a CI event matrix to tests and docs:
  - PR body present / absent
  - branch metadata present / absent
  - merge-ref behavior
  - exactly one changed task file behavior

## Candidate Files
- `.github/workflows/ai-gate.yml`
- `docs/context/CI_PROFILE.md`
- `AGENTS.md`
- `README.md`
- `scripts/ci/run-ai-gate.sh`
- `scripts/open-task-pr.sh`
- `tests/smoke.sh`

## Non-goals
- Do not remove PR body `Task-ID` as a resolver in this phase.
- Do not change local no-arg task resolution yet.
- Do not change freshness or review semantics yet.

## Validation
- CI no longer reads `.context/active_task`.
- CI no longer writes `.context/active_task`.
- Smoke coverage proves the temporary resolver order.
- Ambiguous task identity fails closed.

## Risks
- Resolver narrowing without event-matrix coverage can create noisy CI failures.
- Removing PR body metadata too early would create avoidable incompatibility with existing publish behavior.

## Exit Criteria
- CI task resolution no longer depends on local runtime task state.
- Resolver order is explicit in workflow docs and tests.
- Compatibility fallbacks that remain are documented as temporary and intentional.
