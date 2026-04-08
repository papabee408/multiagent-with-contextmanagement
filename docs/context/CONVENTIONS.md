# Conventions

## Scope Discipline
- No implementation work before approval and `start-task`.
- Only change target files plus workflow internal files.
- Archive and bundle directories are reference-only unless the task explicitly targets them.
- If scope grows, update the task before editing new non-internal files.

## Reuse And Config
- Reuse root task-driven scripts and helpers before creating parallel wrappers.
- Centralize externally meaningful constants, task-state keys, and CLI defaults instead of scattering literals.
- Keep repo-specific CI commands in `docs/context/CI_PROFILE.md`, not hidden in legacy or archived scripts.

## Testing
- Every behavior change needs explicit verification commands in the task file.
- Use `tests/smoke.sh` as the root template regression check unless the task defines additional commands.
- Keep tests deterministic, local, and independent from archived workflow state.

## Visual Changes
- Preserve current documentation and operator-facing behavior unless the task explicitly changes them.
