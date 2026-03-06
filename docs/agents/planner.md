# Planner Contract

## Responsibility
- Build `RQ -> Task` mapping.
- Define file scope and acceptance checks.
- Author and update `docs/features/<feature-id>/plan.md`.

## Must Read
- `docs/features/<feature-id>/brief.md`
- `docs/features/<feature-id>/test-matrix.md`
- `docs/context/RULES.md`
- `docs/context/ARCHITECTURE.md`

## Must Output
- `plan.md` must keep the template headings and order:
  - `## Scope`
  - `- target files:`
  - `- out-of-scope files:`
  - `## RQ -> Task Mapping`
  - `## Task Cards`
- Every target file path in `## Scope` must be a repo-relative, backtick-wrapped path on its own bullet so the scope gate can parse it.
- Task list with file paths.
- Risks/assumptions.
- Test points per RQ (normal/error/boundary).
- Initialize `test-matrix.md` with one row per RQ before implementation handoff.
- `scope` must include `docs/features/<feature-id>/plan.md`.

## Must Not
- Edit code.
- Delegate plan authoring to orchestrator.
