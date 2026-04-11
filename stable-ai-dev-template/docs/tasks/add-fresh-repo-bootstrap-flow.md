# Task: add-fresh-repo-bootstrap-flow

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-11 21:05:22Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-11 20:59:17Z
- approval-note: Approved in chat on 2026-04-11 America/Los_Angeles to publish the fresh-repo bootstrap flow update.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one workflow bootstrap improvement cluster for fresh copied repos and the matching stable bundle mirror
- bundle-override-approved: no

## Goal
- Let a freshly copied repo start with a plain setup request and have the agent bootstrap project context automatically.

## Non-goals
- Do not automate GitHub repository creation or broaden bootstrap into feature implementation.

## Requirements
- RQ-001: Fresh copied repos must have a first-run `init-project.sh` flow that rewrites repo-specific context and creates a bootstrap task.
- RQ-002: Agent guidance must treat requests like "프로젝트 셋팅부터 하자" as authorization to run the bootstrap flow immediately in a fresh copied repo.
- RQ-003: The CI profile setup flow must support non-interactive bootstrap defaults and still emit valid fallback checks.
- RQ-004: Root and `stable-ai-dev-template/` must stay mirrored, and smoke coverage must exercise the stable-bundle-copy bootstrap path.

## Implementation Plan
- Step 1: Add a first-run init script and non-interactive CI profile defaults for copied repos.
- Step 2: Update operator docs so fresh repo setup requests trigger bootstrap without the user memorizing commands.
- Step 3: Mirror the changes into `stable-ai-dev-template/` and extend smoke coverage for the copied-bundle bootstrap path.

## Architecture Notes
- intended module boundaries: keep bootstrap logic in workflow scripts and repo context docs, and keep product runtime code untouched.
- dependency direction: agent guidance triggers the init script, which regenerates repo context and the initial bootstrap task without making the stable bundle a runtime dependency.
- extraction/refactor triggers in touched files: split future bootstrap-only helpers before mixing them with unrelated publish or review logic.

## Target Files
- `AGENTS.md`
- `README.md`
- `docs/tasks/README.md`
- `scripts/init-project.sh`
- `scripts/setup-ci-profile.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/docs/tasks/README.md`
- `stable-ai-dev-template/scripts/init-project.sh`
- `stable-ai-dev-template/scripts/setup-ci-profile.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- remote repo provisioning, secrets setup, and feature-specific product code remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing task lifecycle scripts, CI profile generation flow, and stable bundle mirror pattern.
- config/constants to centralize: keep task branch and PR policy in the existing CI profile and task metadata helpers.
- side effects to avoid: avoid turning fresh bootstrap into a runtime dependency on the stable bundle or requiring users to remember manual setup commands.

## Risk Controls
- sensitive areas touched: git/PR workflow docs, task lifecycle scripts, and stable bundle parity
- extra checks before merge: rerun template sync and smoke after mirroring the new bootstrap flow

## Acceptance
- A repo copied from `stable-ai-dev-template/` can be bootstrapped by running `bash scripts/init-project.sh`, and the documented agent behavior is to do that automatically on a plain project-setup request.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/add-fresh-repo-bootstrap-flow/verification.log
- verification-at-utc: 2026-04-11 21:04:06Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the bootstrap workflow files and the mirrored stable bundle
- scope-review-at-utc: 2026-04-11 21:04:19Z
- quality-review-status: pass
- quality-review-note: reviewed bootstrap reuse, fallback checks, mirrored scope, and architecture placement for the fresh-repo setup flow
- quality-review-at-utc: 2026-04-11 21:04:52Z
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
- next action: create or switch to task/add-fresh-repo-bootstrap-flow, commit the approved diff, publish the PR, and merge after checks pass
- known risks: fresh repo bootstrap should stay narrow and not drift into unrelated workflow automation.

## Completion
- summary: added an automatic fresh-repo bootstrap flow for copied stable bundles and documented the plain setup trigger
- follow-up: create or switch to task/add-fresh-repo-bootstrap-flow, commit the approved diff, publish the PR, and merge after checks pass
