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
`brief.md` chooses the workflow mode (`trivial|lite|full`) and execution mode (`single|multi-agent`).
`plan.md` separately chooses the implementer execution mode (`serial|parallel`).
Workflow mode and execution mode are locked after bootstrap; change them only when the user explicitly asked for it.

## Commands
Start feature (recommended):

```bash
scripts/start-feature.sh <feature-id>
scripts/start-feature.sh --workflow-mode lite --execution-mode single <feature-id>
scripts/start-feature.sh --workflow-mode full --execution-mode multi-agent <feature-id>
```

`start-feature.sh`의 mode 인자는 새 feature packet을 만들 때만 사용한다.
기존 feature packet을 다시 열 때는 `scripts/set-active-feature.sh <feature-id>`만 사용하고, mode 변경은 사용자 승인 후 `promote-workflow.sh` 또는 `workflow-mode.sh` / `execution-mode.sh`의 `--allow-change` 경로로 처리한다.

Create packet directly:

```bash
scripts/feature-packet.sh <feature-id>
scripts/workflow-mode.sh show --feature <feature-id>
scripts/execution-mode.sh show --feature <feature-id>
scripts/workflow-mode.sh role-sequence --feature <feature-id>
scripts/promote-workflow.sh --feature <feature-id> <trivial|lite|full> --reason "<why>"
```

Refresh generated handoffs and test matrix rows after editing `brief.md` or `plan.md`:

```bash
scripts/sync-handoffs.sh <feature-id>
bash scripts/gates/check-implementer-ready.sh --feature <feature-id>
scripts/implementer-subtasks.sh list --feature <feature-id>
scripts/implementer-subtasks.sh validate --feature <feature-id>
```

`implementer`는 위 preflight가 PASS하기 전에는 시작하면 안 된다.

Switch active feature:

```bash
scripts/set-active-feature.sh <feature-id>
```

Run gates:

```bash
scripts/gates/run.sh --fast <feature-id>
scripts/gates/run.sh <feature-id>
```

If `<feature-id>` is omitted, gate runner uses `.context/active_feature`.

Complete feature:

```bash
scripts/complete-feature.sh <feature-id> "<summary>" "<next-step>"
```

`complete-feature.sh`는 completion 중에 생긴 `run-log.md`, current feature artifacts, `HANDOFF/CODEX_RESUME/MAINTENANCE_STATUS`, current completion session log를 기본으로 stage한다.
그래서 final commit/PR/clean-tree 확인은 보통 이 명령 뒤에 둔다.
closeout 파일을 의도적으로 남길 때만 `--no-stage-closeout`를 사용한다.

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
