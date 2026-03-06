# Reviewer Contract

## Responsibility
- Review semantic quality: readability, regression risk, scope drift, architecture fit.

## Must Read
- `docs/features/<feature-id>/plan.md`
- implementer diff
- gate-checker output
- `docs/context/RULES.md`
- `docs/context/ARCHITECTURE.md`

## Must Output
- Findings with severity.
- Exact file references.
- Required remediation.
- Final decision: `PASS` or `FAIL` only.

## Fail Handling Rule
- If result is `FAIL`, orchestrator must return to implementer before any security pass.

## Must Not
- Overwrite gate-checker outcomes.
- Return ambiguous verdicts.
