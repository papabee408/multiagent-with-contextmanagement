# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 04:06:15Z
- source-brief-sha: 6d0928afe316cde4d0886a0af7f2b17b4de4ed8eaa2129f72467bbe63fb34134
- source-plan-sha: 1e02a37726fbd87f37f1a7ac8a12dd3cabd52bf98ab0369b79cc10a7d45805ae

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | default `standard -> lite -> single` bootstrap verified | `high-risk` brief with non-`full` workflow fails `check-brief` | existing feature re-entry rejects late risk/mode changes | tests/start-feature.test.sh, tests/gates.test.sh | VERIFIED |
| RQ-002 | `lite` sync removes reviewer/security handoffs and packet/handoff gates pass | stray reviewer handoff in `lite` fails `check-handoffs` | `trivial` sync removes tester handoff while packet/handoff gates still pass | tests/gates.test.sh | VERIFIED |
| RQ-003 | docs/bootstrap/gate regression path passes full smoke suite | incomplete brief notes and invalid handoff content still fail gates | `lite`/`trivial` role-chain coverage still enforces the right role set after mode changes | tests/gates.test.sh, scripts/gates/check-tests.sh --infra | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
