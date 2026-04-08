# Task: enforce-architecture-review-gate

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-08 17:40:04Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-08 17:37:28Z
- approval-note: Approved in chat on 2026-04-08 America/Los_Angeles to move architecture-review enforcement into a dedicated template-improvement task.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one template-improvement cluster that adds architecture guidance and risk-based architecture review enforcement to the workflow
- bundle-override-approved: no

## Goal
- Add architecture-first guidance to the template and enforce architecture review at the quality gate level without making trivial tasks fail.

## Non-goals
- Do not change branch, merge, or PR metadata policy beyond what the architecture-review gate needs.
- Do not make trivial tasks fail just because `--architecture pass` was omitted.
- Do not introduce a separate runtime dependency between the live template and `stable-ai-dev-template/`.

## Requirements
- RQ-001: Document architecture-first guidance in the operator docs so implementation work maps changes to module boundaries before code is added.
- RQ-002: Add `architecture-review` to the task review surface and require `pass` for `standard` and `high-risk` tasks, while keeping `trivial` tasks warning-only.
- RQ-003: Keep local `check-task` and CI `run-ai-gate` aligned on the new `architecture-review` requirement.
- RQ-004: Update user-facing guidance and smoke coverage so operators see the new flag and a standard-risk task proves the missing flag fails.
- RQ-005: Keep root and `stable-ai-dev-template/` fully mirrored.

## Implementation Plan
- Step 1: Update template guidance docs and task templates with architecture-first rules and the new review field.
- Step 2: Update review and CI scripts to enforce the risk-based `architecture-review` policy.
- Step 3: Update existing done task docs that need the new review field to stay valid under the new schema.
- Step 4: Update smoke coverage and operator guidance for the new review flag and failure mode.

## Architecture Notes
- intended module boundaries: keep durable policy in `docs/context/`, task-contract shape in `docs/tasks/`, enforcement logic in `scripts/`, and end-to-end regression coverage in `tests/smoke.sh`
- dependency direction: docs define the contract, local and CI scripts enforce it, and smoke tests validate the workflow from the outside
- extraction/refactor triggers in touched files: if review dimensions keep growing, extract shared review-dimension evaluation instead of widening inline case blocks further

## Target Files
- `AGENTS.md`
- `README.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/CONVENTIONS.md`
- `docs/tasks/README.md`
- `docs/tasks/_template.md`
- `docs/tasks/migrate-stable-ai-template.md`
- `docs/tasks/simplify-pr-gate-flow.md`
- `docs/tasks/sync-stable-template-bundle.md`
- `scripts/check-task.sh`
- `scripts/ci/run-ai-gate.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/docs/context/ARCHITECTURE.md`
- `stable-ai-dev-template/docs/context/CONVENTIONS.md`
- `stable-ai-dev-template/docs/tasks/README.md`
- `stable-ai-dev-template/docs/tasks/_template.md`
- `stable-ai-dev-template/docs/tasks/migrate-stable-ai-template.md`
- `stable-ai-dev-template/docs/tasks/simplify-pr-gate-flow.md`
- `stable-ai-dev-template/docs/tasks/sync-stable-template-bundle.md`
- `stable-ai-dev-template/scripts/check-task.sh`
- `stable-ai-dev-template/scripts/ci/run-ai-gate.sh`
- `stable-ai-dev-template/scripts/review-quality.sh`
- `stable-ai-dev-template/scripts/review-scope.sh`
- `stable-ai-dev-template/scripts/run-task-checks.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Product feature changes outside the template workflow.
- A broader refactor of task review storage or receipt formats.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing review status fields, task risk levels, CI gate flow, and mirrored stable bundle instead of adding a second review mechanism
- config/constants to centralize: keep risk-based review requirements centralized in the existing review and CI scripts instead of scattering checks across docs and tests
- side effects to avoid: avoid making trivial tasks fail, avoid root-versus-bundle drift, and avoid leaving operator guidance inconsistent with enforced flags

## Risk Controls
- sensitive areas touched: task schema validation, CI merge readiness checks, root-versus-bundle parity, and historical done task docs
- extra checks before merge: rerun `bash scripts/check-template-sync.sh`, rerun `bash tests/smoke.sh`, and verify the PR metadata uses the dedicated task id

## Acceptance
- Operators see explicit architecture-first guidance in the live template docs.
- `review-quality.sh` records `architecture-review` and fails `standard` tasks without it while only warning on `trivial` tasks.
- `check-task.sh` and `scripts/ci/run-ai-gate.sh` require `architecture-review: pass` for non-trivial completed tasks.
- Smoke coverage proves the missing architecture flag fails on a standard-risk task and the mirrored bundle stays in sync.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/enforce-architecture-review-gate/verification.log
- verification-at-utc: 2026-04-08 17:39:33Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the dedicated architecture-review gate task files and mirrored bundle files
- scope-review-at-utc: 2026-04-08 17:39:48Z
- quality-review-status: pass
- quality-review-note: quality review passed: architecture guidance, risk-based gate enforcement, operator guidance, and smoke coverage stay aligned
- quality-review-at-utc: 2026-04-08 17:39:55Z
- reuse-review: pass
- hardcoding-review: pass
- tests-review: pass
- request-scope-review: pass
- architecture-review: pass
- risk-controls-review: n/a

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: auto-recover

## Session Resume
- current focus: task completed; ready to publish from the task branch
- next action: publish from task/enforce-architecture-review-gate after mirroring CURRENT.md and the task doc into stable-ai-dev-template
- known risks: historical task docs must stay valid under the new review field, and operator guidance must not drift from enforced script behavior

## Completion
- summary: added architecture-first template guidance and enforced architecture review for non-trivial tasks
- follow-up: publish from task/enforce-architecture-review-gate after mirroring CURRENT.md and the task doc into stable-ai-dev-template
