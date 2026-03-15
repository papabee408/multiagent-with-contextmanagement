# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `DRAFT | VERIFIED`
- last-updated-utc:
- source-brief-sha:
- source-plan-sha:

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | | | | | |
| RQ-002 | | | | | |

## Notes
- Planner creates one row per RQ before implementation starts.
- Tester fills the executed test file(s) and sets each covered row to `VERIFIED` before returning `PASS`.
- Gate requires top-level status `VERIFIED` and non-empty normal/error/boundary/test-file/status cells for every RQ row.
- Include security/permission/rate-limit tests when applicable.
