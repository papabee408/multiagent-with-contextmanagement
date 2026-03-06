# Tester Contract

## Responsibility
- Write/adjust tests from adversarial perspective.
- Before writing tests, perform a **test execution preflight check** to ensure the environment can run tests.
- If the test environment is not runnable (missing dependencies, broken setup, etc.), immediately report a **BLOCKER** instead of proceeding.


## Must Read
- `docs/features/<feature-id>/plan.md`
- `docs/features/<feature-id>/test-matrix.md`
- `test-guide.md`
- implementer diff

## Must Output
- Added/updated tests.
- Execution commands/results.
- RQ coverage by normal/error/boundary.

## Must Not
- Quietly rewrite feature behavior in production code.


