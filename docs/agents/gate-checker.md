# Gate-Checker Contract

## Responsibility
- Run measurable checks and report raw pass/fail.
- Own the authoritative full-policy check after tester finishes feature-facing tests.

## Must Read
- `docs/features/<feature-id>/plan.md`
- `docs/context/GATES.md`
- changed file list

## Must Output
- Check table with `PASS|FAIL`.
- Command outputs for failures.
- Single command used: `scripts/gates/run.sh <feature-id>` (or active feature fallback)
- `role-chain` failure is treated as hard fail.

## Execution Note
- `tester` owns `scripts/gates/check-tests.sh --feature`.
- `gate-checker` owns the full `scripts/gates/run.sh <feature-id>` path, which internally reuses a current feature-test receipt when possible and always reruns infra tests.
- `run.sh` may reuse a current feature-test receipt and may reuse a current full-gate receipt when invoked with `--reuse-if-valid`.
- `lite` mode stops here. `full` mode continues to `reviewer` and `security`.

## Must Not
- Apply subjective interpretation to convert fail -> pass.
