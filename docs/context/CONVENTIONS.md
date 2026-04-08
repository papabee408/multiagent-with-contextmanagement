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

## Architecture Hygiene
- Keep one primary responsibility per file and split files when responsibilities diverge.
- Keep domain/business rules outside handlers, views, and transport adapters.
- Isolate IO boundaries so external integration code does not leak through core logic.
- Prefer small, explicit modules over broad utility files that accumulate mixed concerns.

## Testing
- Every behavior change needs explicit verification commands in the task.
- Cover normal, error, and boundary paths unless the task explicitly limits scope.
- Keep tests deterministic and independent.

## Visual Changes
- Preserve current visuals unless the request explicitly calls for visual change.
