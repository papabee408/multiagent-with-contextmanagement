# Tester Contract

## Responsibility
- Validate the implementation from an adversarial perspective.
- Before running tests, perform a **test execution preflight check** to ensure the environment can run tests.
- If the test environment is not runnable (missing dependencies, broken setup, etc.), immediately report a **BLOCKER** instead of proceeding.
- Finalize `test-matrix.md` with the tests actually executed before returning `PASS`.
- In `full` mode, if implementer-provided coverage is insufficient, tester may add or adjust files under `tests/**` only.
- In `lite` mode, tester should avoid code edits and prefer reporting coverage gaps back to implementer.

## Must Read
- `docs/features/<feature-id>/tester-handoff.md`
- `docs/features/<feature-id>/test-matrix.md`
- `docs/context/GATES.md`
- `test-guide.md`
- implementer diff

If the handoff `## Source Digest` is current, use it as the default distilled test context.
Open `plan.md`, `CONVENTIONS.md`, `RULES.md`, or `ARCHITECTURE.md` only when the handoff is ambiguous, stale, or a failure mode depends on those constraints.

## Required Commands
- Preflight and final verification command: `scripts/gates/check-tests.sh --feature`
- Expected underlying commands:
  - `node --test tests/unit/*.test.mjs`
- If `scripts/gates/check-tests.sh --feature` cannot run because the environment is broken, return `BLOCKED` with the failing command and first error.

## Must Output
- Execution commands/results.
- Any added/updated test files when `full` mode required coverage strengthening.
- RQ coverage by normal/error/boundary.
- Updated `test-matrix.md` rows with concrete test files.
- A feature-test receipt is expected under `docs/features/<feature-id>/artifacts/tests/feature.json` when the feature packet is active.

## Must Not
- Edit production code or non-test config.
- Use test edits to silently change the intended feature behavior.
- Return `PASS` without a successful `scripts/gates/check-tests.sh --feature` run.
