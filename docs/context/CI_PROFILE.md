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
- `PR Fast Checks`, `High-Risk Checks`, and `Full Project Checks` are supplemental project coverage; prefer commands that add coverage beyond task verification, and `AI Gate` skips repeated commands within the same run.
- This repository is a shell-driven template repo, so `setup-ci-profile.sh` auto-detection is only a starting point and should not replace explicit review.
- The live required regression check is the root `tests/smoke.sh`, not the archived multi-agent shell tests.
