# Conventions

## Scope Discipline
- No implementation work before approval and `start-task`.
- Only change target files plus workflow internal files.
- A target file is not a license for unrelated cleanup.
- If scope grows, update the task before editing new non-internal files.

## Reuse And Config
- Reuse existing modules before adding variants.
- Centralize externally meaningful constants and config.
- Do not scatter magic values across production code.

## Testing
- Every behavior change needs explicit verification commands in the task.
- Cover normal, error, and boundary paths unless the task explicitly limits scope.
- Keep tests deterministic and independent.

## Visual Changes
- Preserve current visuals unless the request explicitly calls for visual change.
