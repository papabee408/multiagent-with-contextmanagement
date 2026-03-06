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
All roles must output these fields in order:
1. `agent`
2. `agent-id` (runtime unique id, must not be reused by another role)
3. `scope`
4. `rq_covered`
5. `rq_missing`
6. `result` (`PASS|FAIL|BLOCKED`)
7. `evidence`
8. `next_action`
