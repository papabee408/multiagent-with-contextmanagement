# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 05:11:14Z
- source-brief-sha: 9a15fe4357b2a8b9654b3881065da2a366f76b80a1b3e8b4577309b1b90f80f7
- source-plan-sha: f0814b3335746180ae7684ff3e8a93fe4c4f9a47e2b3dca199df7d04c96f700e

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | `bash tests/start-feature.test.sh` verifies new briefs seed risk signals as `no` by default | `bash tests/gates.test.sh` fails when `auth-permissions` is `yes` but the brief still claims `standard` | the same gate fixture removes the entire risk-signal section and keeps the legacy brief path valid | `tests/start-feature.test.sh`, `tests/gates.test.sh` | VERIFIED |
| RQ-002 | `bash tests/report-template-kpis.test.sh` verifies workflow mix, override rate, full-gate coverage, and average planner-to-gate-checker minutes | the same KPI smoke keeps one feature without a PASS full-gate receipt and checks that the report surfaces it | `bash tests/context-log.test.sh` covers the zero-feature boundary so KPI reporting still renders stable output during init/monthly | `tests/report-template-kpis.test.sh`, `tests/context-log.test.sh` | VERIFIED |
| RQ-003 | `bash tests/context-log.test.sh` verifies `MAINTENANCE_STATUS.md` includes the workflow KPI block | `bash tests/check-tests-modes.test.sh` and `bash tests/gate-cache.test.sh` would fail if infra maintenance/report smoke wiring were missing | `bash scripts/context-log.sh monthly` generated the real repo maintenance snapshot with KPI target bands and attention lines for the current packet set | `tests/context-log.test.sh`, `tests/check-tests-modes.test.sh`, `tests/gate-cache.test.sh` | VERIFIED |
| RQ-004 | `bash scripts/gates/check-tests.sh --infra` passed after stage-3 doc, gate, KPI, and maintenance changes | `bash tests/gates.test.sh` still rejects contradictory risk routes while `bash tests/check-tests-modes.test.sh` catches missing stage-3 smoke wiring | `bash tests/gates.test.sh` keeps backward-compatible legacy briefs working even without the new risk checklist section | `tests/gates.test.sh`, `tests/check-tests-modes.test.sh`, `tests/gate-cache.test.sh`, `bash scripts/gates/check-tests.sh --infra` | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
