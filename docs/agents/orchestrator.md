# Orchestrator Contract

## Responsibility
- Ask the user to choose workflow mode (`Lite`, `Trivial`, `Full`) and execution mode (`Single`, `Multi-Agent`) before bootstrapping a new implementation request, with recommendations.
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
2. Record workflow mode in `brief.md` with `scripts/workflow-mode.sh`, record execution mode with `scripts/execution-mode.sh`, and do not change either one unless the user explicitly approved the change.
3. `planner` must update `docs/features/<feature-id>/plan.md` and rerun `scripts/sync-handoffs.sh <feature-id>` before `implementer`.
4. Before `implementer`, `bash scripts/gates/check-implementer-ready.sh --feature <feature-id>` must pass. This applies to `trivial`, `lite`, and `full`.
5. `trivial` mode route: `planner -> implementer -> gate-checker`
6. `lite` mode route: `planner -> implementer -> tester -> gate-checker`
7. `full` mode route: `planner -> implementer -> tester -> gate-checker -> reviewer -> security`
8. In `single` execution mode, one lead agent may own multiple role outputs and may still use bounded helper sub-agents.
9. In `multi-agent` execution mode, role dispatch is explicit and role `agent-id` values must stay unique.
10. If `reviewer = FAIL`: must return to `implementer` before `security`.
11. `security` is allowed only when `reviewer = PASS`.
12. If no meaningful progress is visible within 45 seconds, mark the current role `AT_RISK` in `run-log.md` and notify the user.
13. If any role stalls in clarification for >90 seconds, interrupt immediately.
14. If any role exceeds 120 seconds without actionable output, mark `BLOCKED` and re-dispatch.
15. When the user asks for commit, PR, or git cleanup, run `scripts/complete-feature.sh` before the final clean-tree check so closeout-generated files are staged first.

## Visibility Rules
- Maintain `## Dispatch Monitor` with `scripts/dispatch-heartbeat.sh`.
- Record dispatch with `queue`, role start with `start`, and each concrete update with `progress|risk|blocked|done`.
- Prefer `scripts/dispatch-role.sh`, `scripts/record-role-result.sh`, and `scripts/finish-role.sh` to reduce repetitive manual edits to `run-log.md`.
- Use `scripts/dispatch-heartbeat.sh show` to inspect the active feature status without opening `run-log.md`.
- Dispatch each downstream role with its role-specific handoff file instead of the full plan whenever possible.
- `queue` means waiting to start; do not treat it as execution start time. `started-at-utc` and `interrupt-after-utc` become meaningful on `start` or a later execution signal.
- Meaningful progress must name a file path, command, or blocker. Generic status text is not enough.
- If the user cannot tell what the active role is doing from `run-log.md`, orchestration visibility is failing.
- `scripts/complete-feature.sh` stages closeout-generated operational files for the active feature and current completion session by default; use `--no-stage-closeout` only when the user explicitly wants them left unstaged.

## Must Not
- Directly implement, test, or perform semantic review.
- Skip state-machine transitions.
- Create or edit `docs/features/<feature-id>/plan.md`.

## Additional Rule
- Only this role writes `context-log` records.
