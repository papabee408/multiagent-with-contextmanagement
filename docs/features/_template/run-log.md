# Run Log

## Status
- feature-id:
- overall: `IN_PROGRESS | BLOCKED | DONE`

## Dispatch Monitor
- current-role:
- current-status: `QUEUED | RUNNING | AT_RISK | BLOCKED | DONE`
- started-at-utc:
- last-progress-at-utc:
- interrupt-after-utc:
- last-progress:

## Evidence Rule
- `evidence` must name concrete files, commands, diffs, or raw outputs.
- Generic phrases like "investigated", "checked", or "worked on it" are invalid.

## Role Outputs
### orchestrator
- agent-id: (required, unique runtime id)
- scope: (required, orchestration-only, must not include `plan.md`)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### planner
- agent-id: (required, unique runtime id)
- scope: (required, must include `docs/features/<feature-id>/plan.md`)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### implementer
- agent-id: (required, unique runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### tester
- agent-id: (required, unique runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### gate-checker
- agent-id: (required, unique runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### reviewer
- agent-id: (required, unique runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

### security
- agent-id: (required, unique runtime id)
- scope: (required)
- rq_covered: (required)
- rq_missing: (required)
- result: `PASS | FAIL | BLOCKED` (required)
- evidence: (required)
- next_action: (required)

## State-Machine Notes
- If reviewer is `FAIL`, security must be `BLOCKED`.
- Security `PASS` is allowed only when reviewer is `PASS`.
- All `agent-id` values must be unique across roles (single-agent reuse is not allowed).
