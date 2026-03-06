# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-06 20:09:58Z

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | `bash scripts/gates/check-tests.sh` passes with docs + gate regressions | `tests/gates.test.sh` fails when dispatch progress is missing | `tests/gates.test.sh` validates a minimal feature packet with the new monitor fields | `tests/gates.test.sh`, `bash scripts/gates/check-tests.sh` | VERIFIED |
| RQ-002 | `tests/gates.test.sh` passes with `VERIFIED` matrix and populated monitor fields | `tests/gates.test.sh` fails on `DRAFT` matrix status | `tests/gates.test.sh` fails when an RQ row is partially filled | `tests/gates.test.sh` | VERIFIED |
| RQ-003 | `tests/dispatch-heartbeat.test.sh` shows the active feature and updates queue/start/risk/done states | `tests/dispatch-heartbeat.test.sh` rejects an invalid role | `tests/dispatch-heartbeat.test.sh` keeps showing the active feature after multiple state transitions | `tests/dispatch-heartbeat.test.sh` | VERIFIED |

## Notes
- Planner creates one row per RQ before implementation starts.
- Tester fills the executed test file(s) and sets each covered row to `VERIFIED` before returning `PASS`.
- Gate requires top-level status `VERIFIED` and non-empty normal/error/boundary/test-file/status cells for every RQ row.
- Include security/permission/rate-limit tests when applicable.
