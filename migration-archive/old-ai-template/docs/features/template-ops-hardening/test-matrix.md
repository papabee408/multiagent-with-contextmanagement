# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-06 20:09:58Z
- source-brief-sha: 44b248b149b58e1daa807c2bcd399c98953209afc0ee003f4f92dc483fe2b992
- source-plan-sha: e399a69c0ad3cf6a38350364e14274cd6ed854f903d6a6a538445094572baa17

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | `bash scripts/gates/check-tests.sh` passes with docs + gate regressions | `tests/gates.test.sh` fails when dispatch progress is missing | `tests/gates.test.sh` validates a minimal feature packet with the new monitor fields | `tests/gates.test.sh`, `bash scripts/gates/check-tests.sh` | VERIFIED |
| RQ-002 | `tests/gates.test.sh` passes with `VERIFIED` matrix and populated monitor fields | `tests/gates.test.sh` fails on `DRAFT` matrix status | `tests/gates.test.sh` fails when an RQ row is partially filled | `tests/gates.test.sh` | VERIFIED |
| RQ-003 | `tests/dispatch-heartbeat.test.sh` shows the active feature and updates queue/start/risk/done states | `tests/dispatch-heartbeat.test.sh` rejects an invalid role | `tests/dispatch-heartbeat.test.sh` keeps showing the active feature after multiple state transitions | `tests/dispatch-heartbeat.test.sh` | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
