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
Use role-specific `*-handoff.md` files as the default downstream handoff.
Planner refreshes those handoffs by running `scripts/sync-handoffs.sh <feature-id>` after updating `plan.md`.
Each generated handoff carries a `## Source Digest` block. If that digest is current, downstream roles should trust the handoff and avoid reopening upstream docs by default.
Only `planner` should need deep reads of `PROJECT.md` and `ARCHITECTURE.md` in normal flow.
`brief.md` selects workflow mode:
- `lite`: stop after `gate-checker`
- `full`: require `reviewer` and `security`
`plan.md` selects implementer execution mode:
- `serial`: one implementer owns all code edits
- `parallel`: parent implementer may split task cards across subworkers but remains the only merge owner
In normal flow, `implementer` owns production/config edits.
`tester` may strengthen `tests/**` only in `full` mode when coverage is insufficient, and still updates `test-matrix.md` plus verification results.
`reviewer` is the code-quality gate in `full` mode and must evaluate reuse, hardcoding, and obvious performance waste.
Role receipts written via `scripts/record-role-result.sh` must always include `touched_files`, using actual edited project files or `[]`.
Touched-files policy:
- `orchestrator`: feature/context docs only
- `planner`: current feature packet docs only
- `implementer`: `plan.md` target files only
- `tester`: `test-matrix.md`, plus `tests/**` only in `full` mode
- `gate-checker`, `reviewer`, `security`: `[]`

All roles must output these fields in order:
1. `agent`
2. `agent-id` (runtime unique id, must not be reused by another role)
3. `scope`
4. `rq_covered`
5. `rq_missing`
6. `result` (`PASS|FAIL|BLOCKED`)
7. `evidence`
8. `next_action`
