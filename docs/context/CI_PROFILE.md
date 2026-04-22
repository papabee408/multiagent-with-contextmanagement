# CI Profile

## Project Profile
- platform: internal-tooling
- stack: bash-github-actions-template
- package-manager: none
- setup-status: reviewed

## Git / PR Policy
- git-host: github
- default-base-branch: main
- default-branch-strategy: publish-late
- task-branch-pattern: task/<task-id>
- required-check-resolution: branch-protection-first
- merge-method: squash

## Required Check Fallback
- `AI Gate`

## PR Fast Checks
- `bash tests/smoke.sh`

## High-Risk Checks
- `bash tests/smoke.sh`

## Full Project Checks
- `bash tests/smoke.sh`

## Notes
- `AI Gate` already runs `bash scripts/check-context.sh`, `bash scripts/check-task.sh <task-id>`, scope checks, and task verification commands before these project checks.
- Temporary `AI Gate` resolver matrix for this rollout phase:
  - `workflow_dispatch`: prefer explicit `CI_TASK_ID` when manual runs do not have PR metadata, and fail closed if the override does not map to a live task file.
  - `pull_request` with one valid `Task-ID` in the PR body: resolve from PR metadata even when merge refs hide the task branch name.
  - `pull_request` without usable PR metadata: resolve from the task branch name when it matches `task/<task-id>`.
  - invalid, blank, or duplicated PR-body `Task-ID` metadata: fail closed instead of falling through to branch or changed-file inference.
  - malformed or non-existent branch-derived task ids: fail closed instead of falling through to changed-task-file inference.
  - metadata-absent reruns: resolve from exactly one changed live task file when the diff contains one task file and no ambiguity.
  - all other cases: fail closed instead of consulting `.context/active_task`.
- `AI Gate` must not read or write `.context/active_task`; CI runs `check-context.sh` in CI mode so local runtime task pointers stay outside the CI contract.
- `PR Fast Checks`, `High-Risk Checks`, and `Full Project Checks` are supplemental project coverage; prefer commands that add coverage beyond task verification, and `AI Gate` skips repeated commands within the same run.
- This repository is a shell-driven template repo, so `setup-ci-profile.sh` auto-detection is only a starting point and should not replace explicit review.
- The live required regression check is the root `tests/smoke.sh`, not the archived multi-agent shell tests.
