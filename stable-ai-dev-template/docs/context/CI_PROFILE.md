# CI Profile

## Project Profile
- platform: <replace>
- stack: <replace>
- package-manager: none
- setup-status: draft

## PR Fast Checks
Add one backticked command per bullet after setup. Keep this list fast.

## High-Risk Checks
Add extra backticked commands only for sensitive work. Leave empty if not needed yet.

## Full Project Checks
Add slower backticked commands for manual full regression runs.

## Notes
- This file is for project setup and CI wiring, not everyday task context.
- Store platform/framework decisions and CI command policy here so AI sessions do not have to rediscover them from scratch.
- In the three check sections above, keep bullets command-only: `- \`actual command\``.
- Put explanations, caveats, absolute paths, and migration notes here in `## Notes`, not in the command sections.
