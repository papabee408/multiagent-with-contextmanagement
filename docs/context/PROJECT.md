# Project Context

## Identity
- project-name: Stable Task-Driven AI Dev Template
- repo-slug: context+MultiAgentDev
- primary-users: developers and teams running long-lived Codex-assisted product work

## Product Goal
- Provide a copyable root-level template that keeps one user request mapped to one task contract, one PR flow, explicit approval, fresh verification, and lightweight git operations.

## Constraints
- The live workflow must stay copyable as plain repository files with Bash-based automation.
- Runtime state must stay under `.context/` and remain untracked by git.
- Active workflow behavior must come from the root template, not from archived multi-agent packet files.

## Quality Bar
- Preserve the stable task-driven workflow semantics while removing legacy packet and gate machinery.
- Keep repository-specific guidance explicit in root docs and scripts instead of hiding it in archived helpers.
- Prefer smaller, direct workflow surfaces over regenerated orchestration layers.

## Critical Flows
- Bootstrap one task, approve it, implement only inside target files, run verification and reviews, then publish from the task branch.
- Validate pull requests through `AI Gate` using the task file plus repo-specific smoke coverage.
- Generate standalone bootstrap bundles from the live root template with `bash scripts/export-stable-template.sh`; existing-repo migration docs are no longer part of the supported surface.
