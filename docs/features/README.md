# Feature Packets

Quick operator guide:

[`README.md`](../../README.md)

Feature packets keep context scoped per request.
Create one directory per feature:

`docs/features/<feature-id>/`

## Required Files
- `brief.md`: requirements and RQ IDs
- `plan.md`: task/file mapping
- `implementer-handoff.md`: implementation-only distilled context
- `tester-handoff.md`: test-only distilled context
- `reviewer-handoff.md`: review-only distilled context
- `security-handoff.md`: security-only distilled context
- `test-matrix.md`: test coverage map by RQ
- `run-log.md`: role-by-role outputs and status

## Rule
Only the current feature packet should be loaded by role agents.
Downstream roles should read only their handoff file, not the full plan, unless the handoff is insufficient.
`brief.md` chooses the workflow mode (`lite|full`), and `plan.md` chooses the implementer execution mode (`serial|parallel`).

## Commands
Start feature (recommended):

```bash
scripts/start-feature.sh <feature-id>
scripts/start-feature.sh --workflow-mode lite <feature-id>
```

Create packet directly:

```bash
scripts/feature-packet.sh <feature-id>
scripts/workflow-mode.sh show --feature <feature-id>
scripts/workflow-mode.sh role-sequence --feature <feature-id>
```

Refresh generated handoffs and test matrix rows after editing `brief.md` or `plan.md`:

```bash
scripts/sync-handoffs.sh <feature-id>
scripts/implementer-subtasks.sh list --feature <feature-id>
scripts/implementer-subtasks.sh validate --feature <feature-id>
```

Switch active feature:

```bash
scripts/set-active-feature.sh <feature-id>
```

Run gates:

```bash
scripts/gates/run.sh <feature-id>
```

If `<feature-id>` is omitted, gate runner uses `.context/active_feature`.

Complete feature:

```bash
scripts/complete-feature.sh <feature-id> "<summary>" "<next-step>"
```

View or update dispatch monitor:

```bash
scripts/dispatch-heartbeat.sh show
scripts/dispatch-heartbeat.sh start <role> "<message>"
scripts/dispatch-heartbeat.sh progress <role> "<message>"
scripts/dispatch-role.sh <role> "<next action>"
scripts/record-role-result.sh <role> --agent-id <id> --scope "<scope>" --rq-covered "<rq>" --rq-missing "<rq>" --result PASS --evidence "<evidence>" --next-action "<next>"
scripts/finish-role.sh <role> "<done message>" --next-role <role> --next-action "<next action>"
```

## Baseline Snapshot
`scripts/feature-packet.sh` stores pre-existing dirty files in:
`docs/features/<feature-id>/.baseline-changes.txt`

Gate scripts ignore this baseline and evaluate only new changes after packet creation.

## Generated Artifacts
Runtime scripts may create:

- `docs/features/<feature-id>/artifacts/tests/feature.json`
- `docs/features/<feature-id>/artifacts/gates/full.json`
- `docs/features/<feature-id>/artifacts/roles/<role>.json`

These artifacts are machine-readable receipts for test reuse, gate reuse, and role-result verification.
