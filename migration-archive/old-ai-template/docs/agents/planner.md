# Planner Contract

## Responsibility
- Build `RQ -> Task` mapping.
- Define file scope and acceptance checks.
- Author and update `docs/features/<feature-id>/plan.md`.
- Refresh role-specific handoff files and `test-matrix.md` by running `scripts/sync-handoffs.sh <feature-id>` after plan updates.

## Must Read
- `docs/features/<feature-id>/brief.md`
- `docs/features/<feature-id>/test-matrix.md`
- `docs/context/PROJECT.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/GATES.md`

## Must Output
- `plan.md` must keep the template headings and order:
  - `## Scope`
  - `- target files:`
  - `- out-of-scope files:`
  - `## RQ -> Task Mapping`
  - `## Architecture Notes`
  - `## Reuse and Config Plan`
  - `## Execution Strategy`
  - `## Task Cards`
- Every target file path in `## Scope` must be a repo-relative, backtick-wrapped path on its own bullet so the scope gate can parse it.
- `brief.md` must declare `## Workflow Mode` and `## Execution Mode` before implementation dispatch.
- `## Workflow Mode` must use `trivial`, `lite`, or `full`.
- `## Execution Mode` must use `single` or `multi-agent`.
- Task list with file paths.
- `## Architecture Notes` section with:
  - target layer/module placement
  - dependency constraints or forbidden imports
  - where new shared logic should live
- `## Reuse and Config Plan` section with:
  - existing abstractions to reuse
  - extraction candidates
  - constants/config/env centralization plan
  - allowed hardcoded values, if any
- `## Execution Strategy` section with:
  - `implementer mode: serial|parallel`
  - `merge owner: implementer`
  - shared files reserved for the parent implementer, if any
- If `implementer mode = parallel`, task cards must be file-disjoint worker packages that the parent implementer can hand to subworkers.
- Run `scripts/sync-handoffs.sh <feature-id>` so generated handoffs and `test-matrix.md` reflect the latest `plan.md` and `brief.md`.
- Risks/assumptions.
- Test points per RQ (normal/error/boundary).
- Gate expectations per role should already be reflected in the handoff files so downstream roles do not need to reread full gate policy by default.
- Ensure the synced `test-matrix.md` contains one row per RQ before implementation handoff.
- `scope` must include `docs/features/<feature-id>/plan.md` and the handoff files refreshed for dispatch.

## Must Not
- Edit code.
- Delegate plan authoring to orchestrator.
