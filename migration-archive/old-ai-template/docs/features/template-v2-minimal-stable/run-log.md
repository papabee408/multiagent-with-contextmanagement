# Run Log

## Status
- feature-id: template-v2-minimal-stable

## Dispatch Monitor
- current-role:
- current-status: `QUEUED | RUNNING | AT_RISK | BLOCKED | DONE`
- started-at-utc:
- last-progress-at-utc:
- interrupt-after-utc:
- last-progress:
- note: `QUEUED` may leave `started-at-utc` and `interrupt-after-utc` blank until the role actually starts. `start|progress|risk|done|blocked` refresh `interrupt-after-utc` from the latest actionable output, and `guard` may promote stale active work to `AT_RISK` or `BLOCKED` without changing `last-progress-at-utc`.

## Evidence Rule
- `evidence` must name concrete files, commands, diffs, or raw outputs.
- Generic phrases like "investigated", "checked", or "worked on it" are invalid.

## Role Outputs
### orchestrator
- agent-id: (required runtime id)
- scope: (required, orchestration-only, must not include `plan.md`)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### planner
- agent-id: (required runtime id)
- scope: (required, must include `docs/features/<feature-id>/plan.md`)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### implementer
- agent-id: (required runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### tester
- agent-id: (required runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### gate-checker
- agent-id: (required runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### reviewer
- agent-id: (required runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### security
- agent-id: (required runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

## State-Machine Notes
- `trivial` mode requires `orchestrator -> planner -> implementer -> gate-checker`.
- `lite` mode requires `orchestrator -> planner -> implementer -> tester -> gate-checker`.
- `full` mode additionally requires `reviewer -> security`.
- If reviewer is `FAIL`, security must be `BLOCKED`.
- Security `PASS` is allowed only when reviewer is `PASS`.
- `multi-agent` execution mode requires unique `agent-id` values across roles.
- `single` execution mode may reuse the same lead `agent-id` across roles.
