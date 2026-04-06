# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 04:44:18Z
- source-brief-sha: 9276fde623af612eda332da9399d65e91cd54dc12dceb3be574bfd76c13ca06e
- source-plan-sha: a4aed152cf99feb73d5c07705d0d3f56f7034359d9f2165fefeefff3e420b18d

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | `bash tests/dispatch-heartbeat.test.sh` verified start, progress, and done refresh `interrupt-after-utc` from the latest actionable signal | `bash tests/dispatch-heartbeat.test.sh` kept `queue` start-only fields blank and still rejects invalid roles | the same script reuses fixed epochs so the refreshed idle deadline is checked exactly against controlled timestamps | `tests/dispatch-heartbeat.test.sh` | VERIFIED |
| RQ-002 | `bash tests/dispatch-heartbeat.test.sh` verified `guard` promotes stale work to `AT_RISK` and then `BLOCKED` | `bash tests/run-log-ops.test.sh` kept queued next-role handoff state intact instead of treating it as execution start | `guard` fixture checks the 45s and 120s idle windows using deterministic epoch overrides instead of sleeps | `tests/dispatch-heartbeat.test.sh`, `tests/run-log-ops.test.sh` | VERIFIED |
| RQ-003 | `bash tests/gates.test.sh` passed valid `full`, `lite`, and `trivial` role chains with monitor ordering intact | the same gate fixture fails duplicate agent ids, missing progress, and out-of-order tester receipt timestamps | `bash tests/gates.test.sh` covers workflow-mode transitions and receipt timestamp ordering at the boundary between required roles | `tests/gates.test.sh` | VERIFIED |
| RQ-004 | `bash tests/dispatch-heartbeat.test.sh`, `bash tests/run-log-ops.test.sh`, and `bash tests/gates.test.sh` all passed with the default `standard -> lite -> single` packet shape intact | `bash tests/gates.test.sh` still rejects stale/extra workflow artifacts instead of silently widening the fast path | the lite/trivial fixture branches in `bash tests/gates.test.sh` confirm stronger enforcement without reintroducing reviewer/security overhead | `tests/dispatch-heartbeat.test.sh`, `tests/run-log-ops.test.sh`, `tests/gates.test.sh` | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
