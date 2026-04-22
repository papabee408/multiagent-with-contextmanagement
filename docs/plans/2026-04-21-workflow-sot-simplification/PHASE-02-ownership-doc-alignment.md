# Phase 2: Ownership Doc Alignment

## Objective
- Publish a clear ownership matrix without changing behavior.

## Scope
- Align tracked docs on who owns:
  - task contract and task state
  - CI task identity
  - publish truth
  - runtime evidence
  - operator-facing status surfaces
- Turn secondary docs into projections or directory guidance instead of competing authorities.

## Planned Changes
- Write one owner-per-concern matrix into tracked docs.
- Make `AGENTS.md` the canonical workflow authority for behavior rules.
- Keep `README.md` as overview / onboarding / export / bootstrap guidance.
- Reduce `docs/tasks/README.md` to task-directory guidance.
- Reduce `docs/context/RESUME_GUIDE.md` to resume-specific guidance that does not restate the full workflow.
- Ensure docs no longer describe `.context/current.md` or `.context/active_task` as canonical authorities.

## Candidate Files
- `AGENTS.md`
- `README.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/RESUME_GUIDE.md`
- `docs/tasks/README.md`

## Non-goals
- Do not remove any runtime file in this phase.
- Do not change task schema or validator behavior in this phase.

## Validation
- No two tracked docs answer the same ownership question differently.
- The ownership model in docs matches the concrete Phase 1 CI behavior.

## Risks
- Over-collapsing docs can remove useful entry guidance. This phase should reduce contradiction, not erase context.

## Exit Criteria
- A new contributor can tell which file is authoritative for workflow behavior, task state, and runtime evidence without reading contradictory guidance.
