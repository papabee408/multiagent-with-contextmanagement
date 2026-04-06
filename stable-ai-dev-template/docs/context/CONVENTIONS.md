# Conventions

## Scope Discipline
- No implementation work before the task plan is approved.
- Only change files named by the active task.
- A target file is not a license for broad cleanup. Only change the lines and behavior needed for the request.
- Do not change unrelated code paths, naming, layout, styling, or formatting unless the request explicitly requires it.
- If scope grows, update the task contract first.

## Reuse And Config
- Reuse existing modules before adding new variants.
- Centralize externally meaningful constants and config.
- Do not scatter magic values across production code.

## Testing
- Every behavior change needs verification commands in the task.
- Cover normal, error, and boundary paths unless the task explicitly limits scope.
- Keep tests deterministic and independent.

## Visual Changes
- Default stance: preserve current visuals.
- Only alter design when the request explicitly asks for a UX or visual change.
