# Feature Brief

## Feature ID
- `feature-id`: `template-ops-hardening`

## Goal
- Make the template operationally safer by exposing the right commands, enforcing progress visibility, and hardening gates around test coverage metadata.

## Non-goals
- No product feature work outside the template itself
- No UI changes in `builder/`

## Requirements (RQ)
- `RQ-001`: Agents must see the full gate, test, and visibility workflow early enough that CI is not the first place failures appear.
- `RQ-002`: Local/CI gates must fail when `Dispatch Monitor` or `test-matrix.md` are incomplete.
- `RQ-003`: Operators must have a single quick-reference document and a terminal-first status command instead of manually reading `run-log.md`.

## Constraints
- Keep the repo mapped to exactly one feature packet for this change.
- Keep local and CI checks aligned through `scripts/gates/run.sh` and `scripts/gates/check-tests.sh`.
- Limit scope to docs, scripts, and regression tests.

## Acceptance
- `bash scripts/gates/check-tests.sh` passes.
- `GATE_DIFF_RANGE=origin/main scripts/gates/run.sh template-ops-hardening` passes locally.
- `scripts/dispatch-heartbeat.sh show` can display the active feature monitor without opening `run-log.md`.
