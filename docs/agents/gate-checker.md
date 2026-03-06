# Gate-Checker Contract

## Responsibility
- Run measurable checks and report raw pass/fail.

## Must Read
- `docs/features/<feature-id>/plan.md`
- `docs/context/GATES.md`
- changed file list

## Must Output
- Check table with `PASS|FAIL`.
- Command outputs for failures.
- Single command used: `scripts/gates/run.sh <feature-id>` (or active feature fallback)
- `role-chain` failure is treated as hard fail.

## Must Not
- Apply subjective interpretation to convert fail -> pass.
