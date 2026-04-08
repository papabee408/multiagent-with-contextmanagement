# Current Snapshot

- last-updated-utc: 2026-04-08 05:27:24Z
- active-task: simplify-pr-gate-flow
- active-task-file: docs/tasks/simplify-pr-gate-flow.md

## Read This First
1. `docs/context/CURRENT.md`
2. `.context/active_task`
3. `docs/tasks/simplify-pr-gate-flow.md`
4. `docs/context/PROJECT.md`
5. `docs/context/ARCHITECTURE.md`
6. `docs/context/CONVENTIONS.md`
7. `docs/context/CI_PROFILE.md` only if needed
8. `docs/context/DECISIONS.md` only if needed

## Current State
- task-state: done
- risk-level: standard
- approval: approved by user at 2026-04-08 05:22:28Z
- current focus: task completed; ready to publish from the task branch
- next action: publish from task/simplify-pr-gate-flow and let the wrapper repair any existing PR metadata instead of relying on manual body edits
- known risks: smoke coverage is broad, task-doc format changes can ripple through tests, and root versus bundle parity must stay exact

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- current-branch: main
- ahead-of-origin-base: 0
- behind-origin-base: 0
- pr-status: none
- pr-number: none
- pr-url: none
- latest-published-head-sha: none

## Effective Changed Files
- `.github/workflows/ai-gate.yml`
- `docs/context/CURRENT.md`
- `docs/tasks/_template.md`
- `docs/tasks/migrate-stable-ai-template.md`
- `docs/tasks/simplify-pr-gate-flow.md`
- `docs/tasks/sync-stable-template-bundle.md`
- `scripts/_lib.sh`
- `scripts/check-scope.sh`
- `scripts/check-task.sh`
- `scripts/ci/run-ai-gate.sh`
- `scripts/open-task-pr.sh`
- `scripts/refresh-current.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `stable-ai-dev-template/.github/workflows/ai-gate.yml`
- `stable-ai-dev-template/docs/context/CURRENT.md`
- `stable-ai-dev-template/docs/tasks/_template.md`
- `stable-ai-dev-template/docs/tasks/migrate-stable-ai-template.md`
- `stable-ai-dev-template/docs/tasks/simplify-pr-gate-flow.md`
- `stable-ai-dev-template/docs/tasks/sync-stable-template-bundle.md`
- `stable-ai-dev-template/scripts/_lib.sh`
- `stable-ai-dev-template/scripts/check-scope.sh`
- `stable-ai-dev-template/scripts/check-task.sh`
- `stable-ai-dev-template/scripts/ci/run-ai-gate.sh`
- `stable-ai-dev-template/scripts/open-task-pr.sh`
- `stable-ai-dev-template/scripts/refresh-current.sh`
- `stable-ai-dev-template/scripts/review-quality.sh`
- `stable-ai-dev-template/scripts/review-scope.sh`
- `stable-ai-dev-template/scripts/run-task-checks.sh`
- `stable-ai-dev-template/tests/smoke.sh`
- `tests/smoke.sh`

## Verification
- verification-status: pass
- verification-at-utc: 2026-04-08 05:27:03Z

## Reviews
- scope-review-status: pass
- scope-review-at-utc: 2026-04-08 05:27:12Z
- quality-review-status: pass
- quality-review-at-utc: 2026-04-08 05:27:12Z
