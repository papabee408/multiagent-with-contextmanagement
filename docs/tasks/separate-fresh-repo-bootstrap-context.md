# Task: separate-fresh-repo-bootstrap-context

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-12 19:55:48Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-12 19:51:34Z
- approval-note: Approved in chat on 2026-04-12 America/Los_Angeles to publish and merge the fresh-repo bootstrap context split.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one workflow guidance cleanup that narrows first-run bootstrap context loading without changing product behavior
- bundle-override-approved: no

## Goal
- Move the fresh-repo bootstrap policy out of the normal AGENTS read path into a dedicated first-run context file.

## Non-goals
- Do not change `scripts/init-project.sh`, bootstrap behavior, or general task workflow outside the first-run guidance path.

## Requirements
- RQ-001: `AGENTS.md` must direct fresh copied repos to a dedicated bootstrap context file instead of embedding the full bootstrap rule inline.
- RQ-002: The dedicated bootstrap file must preserve the setup trigger phrases, auto-run behavior, and bootstrap-only scope guardrails.
- RQ-003: Smoke coverage must validate the lean AGENTS guidance plus the dedicated first-run bootstrap file in both the root repo and the mirrored stable template.
- RQ-004: The fresh-repo bootstrap seed detection must recognize this new mirrored task file so copied repos can still run `init-project.sh` without `--force`.

## Implementation Plan
- Step 1: Replace the inline fresh-repo rule in `AGENTS.md` with a narrow pointer to a first-run bootstrap context file.
- Step 2: Add `docs/context/FRESH_REPO_BOOTSTRAP.md` with the existing trigger phrases and bootstrap scope guidance, mirrored in `stable-ai-dev-template/`.
- Step 3: Extend the bootstrap seed task allowlist so the new mirrored task file does not break `init-project.sh` in copied repos.
- Step 4: Update smoke assertions to verify the new structure and rerun template-sync plus smoke verification.

## Architecture Notes
- intended module boundaries: keep normal session instructions in `AGENTS.md`, keep first-run bootstrap policy in a dedicated context doc, and keep verification logic in `tests/smoke.sh`.
- dependency direction: AGENTS should conditionally point to the bootstrap doc only for fresh copied repos, and smoke tests should validate the mirrored doc structure without changing runtime bootstrap scripts.
- extraction/refactor triggers in touched files: if more first-run-only guidance accumulates, keep it in dedicated context docs instead of expanding the default AGENTS read path again.

## Target Files
- `AGENTS.md`
- `docs/context/FRESH_REPO_BOOTSTRAP.md`
- `scripts/init-project.sh`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/docs/context/FRESH_REPO_BOOTSTRAP.md`
- `stable-ai-dev-template/scripts/init-project.sh`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- README wording, bootstrap scripts, CI profile generation, and unrelated workflow refactors remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing mirrored template layout, smoke assertion helpers, and the current bootstrap policy text rather than inventing a second bootstrap flow.
- config/constants to centralize: keep the first-run bootstrap wording centralized in the new dedicated context file for each mirrored tree.
- side effects to avoid: avoid widening the default session read path, changing bootstrap runtime behavior, or breaking root/template parity.

## Risk Controls
- sensitive areas touched: operator guidance, template parity, and smoke coverage for fresh copied repos
- extra checks before merge: rerun `bash scripts/check-template-sync.sh` and `bash tests/smoke.sh`

## Acceptance
- Fresh copied repos read a dedicated first-run bootstrap file for setup guidance, while normal AGENTS instructions stay lean and smoke coverage passes for both mirrored trees.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/separate-fresh-repo-bootstrap-context/verification.log
- verification-at-utc: 2026-04-12 19:55:21Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside the bootstrap guidance split, seed allowlist update, and mirrored template files
- scope-review-at-utc: 2026-04-12 19:55:30Z
- quality-review-status: pass
- quality-review-note: reviewed the dedicated first-run bootstrap guidance placement, mirrored seed allowlist update, and smoke coverage updates
- quality-review-at-utc: 2026-04-12 19:55:38Z
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
- next action: create or switch to task/separate-fresh-repo-bootstrap-context, commit the approved diff, publish the PR, merge after checks pass, then sync local main and delete the task branch
- known risks: the root repo and stable template must stay byte-for-byte aligned for the touched mirrored files

## Completion
- summary: split the fresh-repo bootstrap instructions into a first-run context file, mirrored the task file, and updated seed detection plus smoke coverage
- follow-up: create or switch to task/separate-fresh-repo-bootstrap-context, commit the approved diff, publish the PR, merge after checks pass, then sync local main and delete the task branch
