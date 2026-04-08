# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 08:35:24Z
- source-brief-sha: 771c6c064af72cd470159e4ad8206be76e3298f17da9eb24fff694a4bd1194b7
- source-plan-sha: 793877e25768dd56b73000417c8aa320848625a44ac86ed331538d9e062a77ec

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | `bash tests/gates.test.sh` keeps current tester/gate-checker approval hashes passing role-chain | the same smoke mutates approval-target files and fails stale tester/gate-checker PASS receipts | the same smoke verifies approval binding still works across `full`, `lite`, and `trivial` workflow boundaries | `tests/gates.test.sh` | VERIFIED |
| RQ-002 | `bash tests/start-feature.test.sh` still allows normal existing-feature reopen and new packet bootstrap | the same smoke rejects illegal existing-feature overrides before switching `.context/active_feature` | the same smoke proves invalid bootstrap inputs and alerting setup-check reruns do not leave partial state behind | `tests/start-feature.test.sh` | VERIFIED |
| RQ-003 | operator docs now describe common vs mode-specific packet files and approval-bound tester/gate-checker behavior consistently with the enforced gates | the updated docs no longer tell users to keep reviewer/security handoffs in `lite` or `trivial` modes where the gate rejects them | the updated docs explicitly cover the failure boundary where rejected existing-feature overrides must not switch the active feature | `README.md`; `docs/context/GATES.md`; `docs/features/README.md`; `docs/agents/tester.md`; `docs/agents/gate-checker.md` | VERIFIED |
| RQ-004 | `bash scripts/gates/check-tests.sh --full` passes with the new trust guards enabled | the included smoke suite would fail on stale approval binding or unsafe feature re-entry regressions | the combined regression covers targeted shell smokes plus the full suite so the fixes hold at both focused and integrated levels | `tests/gates.test.sh`; `tests/start-feature.test.sh`; `tests/sync-handoffs.test.sh`; `bash scripts/gates/check-tests.sh --full` | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
