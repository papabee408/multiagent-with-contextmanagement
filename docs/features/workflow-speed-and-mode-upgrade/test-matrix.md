# Test Matrix

## Status
- owner-init: `planner`
- owner-verify: `tester`
- status: `VERIFIED`
- last-updated-utc: 2026-03-27 02:38:41Z
- source-brief-sha: 5d50a5b508263c66c9d3b17c84d5f579542f0d9ecc20ebd8a6ba6d1e4a40d888
- source-plan-sha: 2a3d7957e212686b05757ee1c32ec4186bcf2db2c60f83a92d883ce714623c17

## Coverage
| RQ | Normal | Error | Boundary | Test File | Status |
|---|---|---|---|---|---|
| RQ-001 | documented workflow/execution choice flow is present and recommended-first guidance is covered | invalid or missing mode guidance fails handoff/gate fixtures | `trivial`, `lite`, `full`, `single`, `multi-agent` edges are exercised | tests/workflow-mode.test.sh; tests/execution-mode.test.sh; tests/gates.test.sh | VERIFIED |
| RQ-002 | locked mode changes require explicit `--allow-change` paths | silent mode change attempts fail in workflow/execution mode commands | re-entering an existing feature through `start-feature.sh` cannot bypass the lock | tests/workflow-mode.test.sh; tests/execution-mode.test.sh; tests/start-feature.test.sh | VERIFIED |
| RQ-003 | upward workflow promotion succeeds and keeps the same feature packet | downward workflow changes are rejected | `trivial` and `lite` role-chain shapes are validated against extra-role failures | tests/promote-workflow.test.sh; tests/workflow-mode.test.sh; tests/gates.test.sh | VERIFIED |
| RQ-004 | `single` mode can reuse one lead agent across roles in the final packet | unauthorized `multi-agent` switch attempts fail | duplicate agent ids in `multi-agent` mode fail role-chain | tests/execution-mode.test.sh; tests/gates.test.sh | VERIFIED |
| RQ-005 | reviewer/security approval receipts bind to the current approval-target hash | stale reviewer/security approvals fail role-chain | closeout-only files stay outside approval invalidation while plan/code changes still invalidate approval | tests/gates.test.sh; tests/gate-cache.test.sh | VERIFIED |
| RQ-006 | `scripts/gates/run.sh --fast` reuses feature-test receipts and skips full-gate receipt writes | clean worktrees no longer fall back to previous-commit diffs | feature-only vs infra-only test paths remain separated and cached correctly | tests/gate-cache.test.sh; tests/check-tests-modes.test.sh; tests/gates.test.sh | VERIFIED |
| RQ-007 | implementer dispatch succeeds only after `brief`, `plan`, and `handoffs` are ready | preflight failure blocks implementer dispatch | the same preflight rule applies before a queued implementer transition is allowed | tests/run-log-ops.test.sh; tests/gates.test.sh | VERIFIED |
| RQ-008 | `complete-feature.sh` stages changed closeout files for the active feature/session | `--no-stage-closeout` remains the opt-out path through docs/contracts | unrelated files remain outside the scoped closeout staging set | tests/stage-closeout.test.sh; tests/gate-cache.test.sh | VERIFIED |
| RQ-009 | queued monitor states can leave start/interrupt timestamps blank until real execution starts | invalid placeholder monitor fields fail role-chain | started/done monitor states require concrete timestamps and progress messages | tests/run-log-ops.test.sh; tests/gates.test.sh; tests/dispatch-heartbeat.test.sh | VERIFIED |

## Notes
- Generated and refreshed by `scripts/sync-handoffs.sh` from `brief.md`.
- Planner owns RQ row shape. Tester owns concrete coverage and final `VERIFIED` transition.
