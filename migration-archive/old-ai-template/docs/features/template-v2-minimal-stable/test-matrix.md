# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 09:34:00Z
- source-brief-sha: b75f1f3cfe58a41dcf433c7728950d2bc3cea49ed94165a2ba3f6864c497d5b8
- source-plan-sha: 5334be97a17fa38dc13d02d280a6a41bec1410b6b6d66e1ced9b88a0ca96b807

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | smoke test boots a task and refreshes `CURRENT.md` from the new template flow | placeholder context/task inputs fail validation before work proceeds | no active task snapshot stays readable until a task is bootstrapped | stable-ai-dev-template/tests/smoke.sh | VERIFIED |
| RQ-002 | scope check passes when only task-approved files change | scope check fails when `notes.txt` changes outside task targets after baseline capture | unchanged pre-existing dirty file is ignored until it changes again | stable-ai-dev-template/tests/smoke.sh | VERIFIED |
| RQ-003 | verification receipt is written and completion passes when fingerprint is fresh | completion fails when receipt is missing or stale | changing a target file after verification invalidates completion immediately | stable-ai-dev-template/tests/smoke.sh | VERIFIED |
| RQ-004 | smoke script exercises the intended happy path end to end | smoke script exits non-zero if scope or freshness protections regress | temporary copy of the template proves the workflow without mutating this repo | stable-ai-dev-template/tests/smoke.sh | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
