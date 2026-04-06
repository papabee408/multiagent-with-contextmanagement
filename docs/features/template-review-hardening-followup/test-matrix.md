# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 07:55:50Z
- source-brief-sha: e8514c7e26d6b20fbfa5a30c06342b23da6f46856faf1226b43e1f2ecf1dd46d
- source-plan-sha: 36720188a8e561a19b6dfa98ec26b480b1c7697414f3657932c109e6011b6018

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | unchanged rerun preserves VERIFIED coverage | brief or plan digest drift resets the matrix to DRAFT | brief-only and plan-only source changes both invalidate verified coverage | tests/sync-handoffs.test.sh | VERIFIED |
| RQ-002 | current feature packet docs still pass scope | unrelated docs/context policy file changes fail scope | only workflow-owned packet and closeout artifacts bypass plan-target checks | tests/gates.test.sh | VERIFIED |
| RQ-003 | populated required context sections pass project-context | structurally present but empty required sections fail | missing required gate item names in GATES.md also fail | tests/gates.test.sh | VERIFIED |
| RQ-004 | current sync-script digest passes handoff validation | stale sync-script digest fails handoff validation | workflow-mode sync removes or rejects stray handoff files outside the active mode | tests/gates.test.sh | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
