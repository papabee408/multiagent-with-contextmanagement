# Phase 7: PR Cache Dependency Removal

## Objective
- Remove correctness dependence on local PR cache files such as `.context/tasks/<task-id>/pr.env`.

## Scope
- Make publish, land, and status flows resolve PR state from GitHub or branch state directly.
- Keep a cache only if it is clearly non-authoritative and optional.

## Planned Changes
- Audit every place that reads `pr.env`.
- Teach publish/land/status flows to recover directly from GitHub and branch state without requiring local cache files.
- If a tiny cache remains useful, mark it explicitly as optional and non-authoritative.

## Candidate Files
- `scripts/_lib.sh`
- `scripts/land-task.sh`
- `scripts/open-task-pr.sh`
- `scripts/status-task.sh`
- `tests/smoke.sh`

## Non-goals
- Do not change local task selection in this phase.
- Do not delete unrelated helper scripts in this phase.

## Validation
- Publish and land succeed without `pr.env`.
- Status rendering remains useful when cache files are absent.

## Risks
- Over-coupling local status to live remote state can hurt offline usability. Remote data should be optional where possible.

## Exit Criteria
- `pr.env` is not required for correctness.
- Any remaining PR cache is explicitly optional.
