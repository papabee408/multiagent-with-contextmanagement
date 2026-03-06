# Tester Contract

## Responsibility
- Write/adjust tests from adversarial perspective.
- Before writing tests, perform a **test execution preflight check** to ensure the environment can run tests.
- If the test environment is not runnable (missing dependencies, broken setup, etc.), immediately report a **BLOCKER** instead of proceeding.
- Finalize `test-matrix.md` with the tests actually executed before returning `PASS`.


## Must Read
- `docs/features/<feature-id>/plan.md`
- `docs/features/<feature-id>/test-matrix.md`
- `docs/context/GATES.md`
- `test-guide.md`
- implementer diff

## Required Commands
- Preflight and final verification command: `scripts/gates/check-tests.sh`
- Expected underlying commands:
  - `node --test tests/unit/*.test.mjs`
  - `bash tests/context-log.test.sh`
- If `scripts/gates/check-tests.sh` cannot run because the environment is broken, return `BLOCKED` with the failing command and first error.

## Must Output
- Added/updated tests.
- Execution commands/results.
- RQ coverage by normal/error/boundary.
- Updated `test-matrix.md` rows with concrete test files.

## Must Not
- Quietly rewrite feature behavior in production code.
- Return `PASS` without a successful `scripts/gates/check-tests.sh` run.

