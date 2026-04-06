# Agent Roles

Use one role file per active role.
Do not load all role files in a single pass.

## Files
- `orchestrator.md`
- `planner.md`
- `implementer.md`
- `tester.md`
- `gate-checker.md`
- `reviewer.md`
- `security.md`

## Global Contract
For new work, default to risk class `standard`, workflow mode `lite`, and execution mode `single`.
Use the brief risk-signal checklist to decide whether the request is still `standard`, can drop to `trivial`, or must become `high-risk -> full`.
Ask the user only when overriding the default workflow route or enabling `Multi-Agent`.
`Multi-Agent` requires explicit user opt-in, and chosen modes stay locked until the user explicitly asks to change them.
Use role-specific `*-handoff.md` files as the default downstream handoff.
Planner refreshes those handoffs by running `scripts/sync-handoffs.sh <feature-id>` after updating `plan.md`.
Before `implementer` starts, `bash scripts/gates/check-implementer-ready.sh --feature <feature-id>` must pass. That preflight requires current `brief`, `plan`, and synced handoffs.
Each generated handoff carries a `## Source Digest` block. If that digest is current, downstream roles should trust the handoff and avoid reopening upstream docs by default.
Only `planner` should need deep reads of `PROJECT.md` and `ARCHITECTURE.md` in normal flow.
`brief.md` selects workflow mode:
- `trivial`: stop after `gate-checker`, skip `tester`
- `lite`: require `tester`, stop after `gate-checker`
- `full`: require `reviewer` and `security`
`brief.md` also selects execution mode:
- `single`: one lead agent may own multiple roles; helper sub-agents stay optional and bounded
- `multi-agent`: explicit role-level delegation; role `agent-id` values must stay unique
`plan.md` selects implementer execution mode:
- `serial`: one implementer owns all code edits
- `parallel`: parent implementer may split task cards across subworkers but remains the only merge owner
In normal flow, `implementer` owns production/config edits.
In `trivial` mode, `implementer` also finalizes `test-matrix.md`.
`tester` may strengthen `tests/**` only in `full` mode when coverage is insufficient, and still updates `test-matrix.md` plus verification results.
`reviewer` is the code-quality gate in `full` mode and must evaluate reuse, hardcoding, and obvious performance waste.
Role receipts written via `scripts/record-role-result.sh` must always include `touched_files`, using actual edited project files or `[]`.
Touched-files policy:
- `orchestrator`: feature/context docs only
- `planner`: current feature packet docs only
- `implementer`: `plan.md` target files only, plus `test-matrix.md` in `trivial` mode
- `tester`: `test-matrix.md`, plus `tests/**` only in `full` mode
- `gate-checker`, `reviewer`, `security`: `[]`

All roles must output these fields in order:
1. `agent`
2. `agent-id` (runtime id; unique across roles only in `multi-agent` execution mode)
3. `scope`
4. `rq_covered`
5. `rq_missing`
6. `result` (`PASS|FAIL|BLOCKED`)
7. `evidence`
8. `next_action`
