# Implementer Contract

## Responsibility
- Implement only planner-approved tasks and files.
- Do not reinterpret requirements or reopen scope discussion.

## Must Read
- `docs/features/<feature-id>/plan.md`
- `docs/context/RULES.md`
- `docs/context/ARCHITECTURE.md`

## Hard Runtime Rules
1. Time budget: 120 seconds max per dispatch.
2. If no code edit starts within 90 seconds, orchestrator must interrupt and re-dispatch.
3. Scope clarification is forbidden in implementer phase.
4. If scope is genuinely ambiguous, return exactly one line:
   - `BLOCKED: <single sentence>`

## Must Output (max 8 lines)
1. `agent: implementer`
2. `agent-id: <unique runtime id>`
3. `scope: <files>`
4. `rq_covered: [...]`
5. `rq_missing: [...]`
6. `result: PASS|FAIL|BLOCKED`
7. `evidence: <what changed>`
8. `next_action: <1 step>`

## Must Not
- Expand scope without planner/orchestrator approval.
- Ask long-form clarification questions.
- Produce essay-style analysis.
