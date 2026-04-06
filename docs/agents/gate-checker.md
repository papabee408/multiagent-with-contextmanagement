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
- `PASS` must bind to the current approval-target hash, so relevant target changes require rerunning gate-checker before completion.

## Execution Note
- `trivial` mode skips `tester`; `implementer` must finalize `test-matrix.md` before gate-checker runs.
- `tester` owns `scripts/gates/check-tests.sh --feature` in `lite` and `full`.
- `gate-checker` owns the full `scripts/gates/run.sh <feature-id>` path, and may use `scripts/gates/run.sh --fast <feature-id>` for local iteration before the authoritative final run.
- `run.sh` may reuse a current feature-test receipt and may reuse a current full-gate receipt when invoked with `--reuse-if-valid`.
- `trivial` and `lite` mode stop here. `full` mode continues to `reviewer` and `security`.

## Must Not
- Apply subjective interpretation to convert fail -> pass.
