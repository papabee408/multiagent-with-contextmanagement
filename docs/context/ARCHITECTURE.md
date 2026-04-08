# Architecture

## System Map
- entry/application: `.github/workflows/ai-gate.yml`, `AGENTS.md`, and task lifecycle scripts in `scripts/*.sh`
- domain/feature: task contracts in `docs/tasks/*.md` and workflow policy docs in `docs/context/*.md`
- infrastructure/integration: git and GitHub CLI integration inside publish/merge scripts plus local runtime state under `.context/`
- shared: `scripts/_lib.sh`, `test-guide.md`, and `tests/smoke.sh`

## Module Boundaries
- Root task scripts own state transitions, verification receipts, and PR automation.
- Task contracts under `docs/tasks/` own request scope, verification commands, and review summaries.
- Context docs under `docs/context/` own reusable repo policy, not request-local state.
- `stable-ai-dev-template/` mirrors the live template for copy/bootstrap workflows and must not be imported as a runtime dependency.

## Dependency Rules
- allowed: workflow entrypoints call shared shell helpers, read task/context docs, and read local `.context/` runtime state
- forbidden: live root scripts depending on archived multi-agent packet files or treating the archive as active state

## Placement Rules
- new business logic: place it in root task lifecycle scripts or task/context docs, depending on whether it is executable workflow logic or durable policy
- new IO or adapter code: place it in `scripts/` or `scripts/ci/` when it integrates with git, GitHub, or CI
- new shared abstractions: place them in `scripts/_lib.sh` or a narrow shared helper only when multiple root scripts need the same behavior
