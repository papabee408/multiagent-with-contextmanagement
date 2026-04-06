# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 03:19:00Z
- source-brief-sha: 344719220060467097fa904c7d3e669eb21eeaccb2478cc4f031856d383d0bc4
- source-plan-sha: a4e10699ca7879f4ed62cabf5a0b42daca177e6bb4ce065249865bb52eb5f749

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | `tests/start-feature.test.sh` verifies normal bootstrap produces packet files with `feature-id` schema keys intact and a clean `.baseline-changes.txt` | `tests/start-feature.test.sh` verifies replacing feature IDs does not produce invalid schema keys and `check-brief` fails for malformed generated packet data | `tests/start-feature.test.sh` verifies alerted bootstrap runs at most once and `start-feature` remains idempotent across boundary runs (`feature-2` and `feature-3`) | `tests/start-feature.test.sh` | VERIFIED |
| RQ-002 | `tests/gates.test.sh` verifies valid `PROJECT.md` + `GATES.md` content passes `check-project-context` | `tests/gates.test.sh` mutates `GATES.md` to break required item set and expects project-context validation failure | `tests/gates.test.sh` also checks placeholder/missing gate metadata edge-cases in the policy fixture | `tests/gates.test.sh` | VERIFIED |
| RQ-003 | `tests/start-feature.test.sh` verifies initial alerted setup bootstrap writes one alert and completes; feature creation still updates run-log and active feature | `tests/start-feature.test.sh` validates invalid mode re-entry for an existing feature is rejected | `tests/start-feature.test.sh` verifies alert flag in `.context/setup-check.done` persists and suppresses redundant setup checks on rerun | `tests/start-feature.test.sh` | VERIFIED |
| RQ-004 | `tests/export-template.test.sh` verifies exported template contains required structural dirs (`scripts`, `docs/context`, `docs/features/_template`, etc.) | `tests/export-template.test.sh` confirms excluded docs (`Handoff`, `CODEX_RESUME`, `MAINTENANCE_STATUS`) are not copied | `tests/export-template.test.sh` verifies session logs/old context sessions are absent from the export bundle | `tests/export-template.test.sh` | VERIFIED |
| RQ-005 | `bash scripts/gates/check-tests.sh --feature`, `tests/check-tests-modes.test.sh`, `tests/gate-cache.test.sh` verify feature/infra/full test routing and cache reuse paths on the happy flow | `tests/check-tests-modes.test.sh` verifies infra-only mode does not execute feature tests and vice versa; `tests/gate-cache.test.sh` verifies cache-invalid conditions are caught | `tests/gate-cache.test.sh` verifies fast/full/reuse execution boundaries including receipt reuse and staging behavior during completion | `scripts/gates/check-tests.sh`, `tests/start-feature.test.sh`, `tests/export-template.test.sh`, `tests/gates.test.sh`, `tests/check-tests-modes.test.sh`, `tests/gate-cache.test.sh` | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
