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

## Product Code Guardrails
- Keep one primary responsibility per file/module and avoid stacking unrelated behavior in one file.
- Keep entry or UI handlers thin; they should orchestrate and delegate, not own business rules.
- Keep business rules in domain modules that are independent of IO details.
- Keep IO concerns (filesystem, network, database, third-party APIs) in adapter/infrastructure modules.
- Dependencies should point inward toward domain logic, not outward from domain to adapters.

## Dependency Rules
- allowed: workflow entrypoints call shared shell helpers, read task/context docs, and read local `.context/` runtime state
- forbidden: live root scripts depending on archived multi-agent packet files or treating the archive as active state

## Placement Rules
- new business logic: place it in root task lifecycle scripts or task/context docs, depending on whether it is executable workflow logic or durable policy
- new IO or adapter code: place it in `scripts/` or `scripts/ci/` when it integrates with git, GitHub, or CI
- new shared abstractions: place them in `scripts/_lib.sh` or a narrow shared helper only when multiple root scripts need the same behavior

## Refactor Triggers
- Extract a new module when a touched file starts carrying more than one change reason.
- Extract before adding a second unrelated concern to the same file, even if it seems faster short-term.
- If extraction must be deferred for scope reasons, record the risk and follow-up in the task file.
