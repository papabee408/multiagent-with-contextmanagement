# CI Profile

## Project Profile
- platform: <replace>
- stack: <replace>
- package-manager: <replace>
- setup-status: draft

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
- `replace with the fastest reliable lint/typecheck/test command`

## High-Risk Checks
- `replace with extra commands only for sensitive changes`

## Full Project Checks
- `replace with slower full regression commands`

## Notes
- Keep command sections command-only: `- \`actual command\``
- Put explanations and caveats in `## Notes`, not inside command sections.
