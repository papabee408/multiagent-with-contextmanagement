# Orchestrator Contract

## Responsibility
- Convert user request to `RQ-xxx` list.
- Dispatch role sequence and context slices.
- Integrate results and decide next step.
- Keep orchestration-only ownership. Planning content authoring belongs to `planner`.

## Must Read
- `docs/features/<feature-id>/brief.md`
- `docs/features/<feature-id>/run-log.md`
- `docs/context/HANDOFF.md`
- `docs/context/CODEX_RESUME.md`

## Hard State Machine
1. `planner` must update `docs/features/<feature-id>/plan.md` and return `PASS` before `implementer`.
2. `planner -> implementer -> tester -> gate-checker -> reviewer -> security`
3. If `reviewer = FAIL`: must return to `implementer` before `security`.
4. `security` is allowed only when `reviewer = PASS`.
5. If any role stalls in clarification for >90 seconds, interrupt immediately.
6. If any role exceeds 120 seconds without actionable output, mark `BLOCKED` and re-dispatch.

## Must Not
- Directly implement, test, or perform semantic review.
- Skip state-machine transitions.
- Create or edit `docs/features/<feature-id>/plan.md`.

## Additional Rule
- Only this role writes `context-log` records.
