# Orchestrator Contract

## Responsibility
- Convert user request to `RQ-xxx` list.
- Ensure the feature packet exists before role dispatch.
- Dispatch role sequence and context slices.
- Integrate results and decide next step.
- Keep live progress visible in `run-log.md`.
- Keep orchestration-only ownership. Planning content authoring belongs to `planner`.

## Must Read
- `docs/features/<feature-id>/brief.md`
- `docs/features/<feature-id>/run-log.md`
- `docs/context/PROJECT.md`
- `docs/context/GATES.md`
- `docs/context/HANDOFF.md`
- `docs/context/CODEX_RESUME.md`

Read `GATES.md` only for workflow state machine, completion policy, and merge-blocking semantics. Detailed verification expectations belong in planner handoffs.

## Hard State Machine
1. Before the first role dispatch, run `scripts/start-feature.sh <feature-id>` or confirm the packet already exists.
2. Confirm workflow mode from `brief.md` with `scripts/workflow-mode.sh show --feature <feature-id>`.
3. `planner` must update `docs/features/<feature-id>/plan.md` and rerun `scripts/sync-handoffs.sh <feature-id>` before `implementer`.
4. `lite` mode route: `planner -> implementer -> tester -> gate-checker`
5. `full` mode route: `planner -> implementer -> tester -> gate-checker -> reviewer -> security`
6. If `reviewer = FAIL`: must return to `implementer` before `security`.
7. `security` is allowed only when `reviewer = PASS`.
8. If no meaningful progress is visible within 45 seconds, mark the current role `AT_RISK` in `run-log.md` and notify the user.
9. If any role stalls in clarification for >90 seconds, interrupt immediately.
10. If any role exceeds 120 seconds without actionable output, mark `BLOCKED` and re-dispatch.

## Visibility Rules
- Maintain `## Dispatch Monitor` with `scripts/dispatch-heartbeat.sh`.
- Record dispatch with `queue`, role start with `start`, and each concrete update with `progress|risk|blocked|done`.
- Prefer `scripts/dispatch-role.sh`, `scripts/record-role-result.sh`, and `scripts/finish-role.sh` to reduce repetitive manual edits to `run-log.md`.
- Use `scripts/dispatch-heartbeat.sh show` to inspect the active feature status without opening `run-log.md`.
- Dispatch each downstream role with its role-specific handoff file instead of the full plan whenever possible.
- Meaningful progress must name a file path, command, or blocker. Generic status text is not enough.
- If the user cannot tell what the active role is doing from `run-log.md`, orchestration visibility is failing.

## Must Not
- Directly implement, test, or perform semantic review.
- Skip state-machine transitions.
- Create or edit `docs/features/<feature-id>/plan.md`.

## Additional Rule
- Only this role writes `context-log` records.
