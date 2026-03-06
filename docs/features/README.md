# Feature Packets

Quick operator guide:

[`README.md`](../../README.md)

Feature packets keep context scoped per request.
Create one directory per feature:

`docs/features/<feature-id>/`

## Required Files
- `brief.md`: requirements and RQ IDs
- `plan.md`: task/file mapping
- `test-matrix.md`: test coverage map by RQ
- `run-log.md`: role-by-role outputs and status

## Rule
Only the current feature packet should be loaded by role agents.

## Commands
Start feature (recommended):

```bash
scripts/start-feature.sh <feature-id>
```

Create packet directly:

```bash
scripts/feature-packet.sh <feature-id>
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
```

## Baseline Snapshot
`scripts/feature-packet.sh` stores pre-existing dirty files in:
`docs/features/<feature-id>/.baseline-changes.txt`

Gate scripts ignore this baseline and evaluate only new changes after packet creation.
