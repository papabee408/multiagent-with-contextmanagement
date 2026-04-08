# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 07:12:54Z
- source-brief-sha: 2c4efa470bd867dece419fb52b6fa2e2630cc2ceb3dd46daaf81622d0a35bb9a
- source-plan-sha: a757e487dead25086b37266abd2d701a719f04b7cea78c831dbb799d6dd0962a

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | `bash tests/start-feature.test.sh` keeps valid default/high-risk feature bootstrap working after the prevalidation change | the same smoke rejects `--risk-class nope` and verifies no partial packet or active-feature switch is left behind | the same smoke still rejects mode-changing re-entry on an existing feature while keeping the original active feature intact | `tests/start-feature.test.sh` | VERIFIED |
| RQ-002 | `bash tests/gate-cache.test.sh` still reuses a fresh PASS full-gate receipt when inputs are unchanged | the same smoke commits a broken infra test and verifies `scripts/gates/run.sh --reuse-if-valid feature-1` reruns tests and fails instead of reusing stale PASS output | the same smoke covers the clean-worktree boundary by proving a committed infra-test change invalidates cache reuse even after the previous PASS receipt was committed | `tests/gate-cache.test.sh` | VERIFIED |
| RQ-003 | `bash tests/start-feature.test.sh` keeps feature bootstrap succeeding during alerting setup-check runs while leaving no false success stamp behind | the same smoke proves alerting setup checks rerun until the fixture passes | the same smoke proves a later passing setup check writes `status=ok` once and suppresses further reruns on subsequent `start-feature.sh` calls | `tests/start-feature.test.sh` | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
