# Phase 6: Freshness Dual-Write, Gate Switch, And Receipt Retirement

## Objective
- Replace receipt-file freshness with tracked task-file freshness while preserving stale-review protection throughout the migration.

## Why This Phase Is Safety-Critical
- This phase changes the mechanism that currently blocks publish after reviewed-diff drift.
- It must be executed as an explicit compatibility migration, not a cutover by implication.

## Concrete Tracked Freshness Schema
- Add tracked fingerprint fields:
  - `verification-fingerprint` under `## Verification Status`
  - `scope-review-fingerprint` under `## Review Status`
  - `quality-review-fingerprint` under `## Review Status`
- Fingerprints must represent the current task contract plus non-internal changed-file digests, matching the current runtime freshness model.

## Migration Stages
- Stage A: Dual-write
  - verification and review scripts write both runtime receipts and tracked fingerprint fields
  - validators and gates accept legacy receipt-only tasks and dual-write tasks
- Stage B: Gate switch
  - `check-task.sh`, `run-ai-gate.sh`, `complete-task.sh`, `open-task-pr.sh`, and `land-task.sh` prefer tracked freshness when present
  - receipt files remain as compatibility fallback
- Stage C: Receipt retirement
  - remove correctness dependence on receipt files
  - update or retire receipt-based reporting

## Planned Changes
- Reuse the existing fingerprint logic instead of inventing a new freshness model.
- Preserve phase-specific freshness rather than collapsing everything into one coarse stamp.
- Keep verification logs unless they clearly become unnecessary.
- Define backward-compat behavior explicitly so historical task docs remain valid.

## Candidate Files
- `docs/tasks/_template.md`
- `scripts/_lib.sh`
- `scripts/check-task.sh`
- `scripts/ci/run-ai-gate.sh`
- `scripts/complete-task.sh`
- `scripts/land-task.sh`
- `scripts/open-task-pr.sh`
- `scripts/record-task-metrics.sh`
- `scripts/report-template-health.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `tests/smoke.sh`

## Non-goals
- Do not weaken freshness to commit SHA only.
- Do not remove phase-specific review signals.

## Required Safety Properties
- Verification freshness, scope-review freshness, and quality-review freshness remain independently representable.
- Drift detection still notices staged, unstaged, and untracked in-scope changes under `publish-late`.
- Publish and CI gates reject stale tracked freshness after the switch.
- Legacy completed tasks remain readable and acceptable during compatibility.

## Validation
- Smoke coverage proves dual-write works.
- Smoke coverage proves gate switch works.
- Smoke coverage proves stale reviewed state still blocks publish and land after receipt retirement.

## Risks
- A partial migration could leave tracked fields and runtime receipts disagreeing.
- Reporting scripts may silently become wrong if they are not updated during the same phase.

## Exit Criteria
- Tracked freshness is the canonical correctness mechanism.
- Receipt files are no longer required for merge-readiness.
- Backward-compat behavior is explicit in validators and tests.
