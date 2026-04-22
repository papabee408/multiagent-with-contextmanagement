# Phase 3: Status Command Introduction

## Objective
- Introduce a non-canonical replacement for the persisted dashboard before removing `.context/current.md`.

## Scope
- Add an explicit status command that renders current task status on demand.
- Keep the persisted dashboard during the compatibility window.

## Concrete Migration Rule
- Introduce `scripts/status-task.sh` as the replacement status surface.
- The new command must work locally and remain useful even when remote PR metadata is unavailable.
- During this phase, `status-task.sh` and the persisted dashboard coexist.

## Planned Changes
- Build `scripts/status-task.sh` from task file state, git state, and optional PR lookup.
- Ensure the rendered output covers the current operator needs:
  - active task
  - task state
  - next action
  - changed files
  - risk
  - verification failure path / log hint
  - available PR status when resolvable
- Update docs and smoke coverage to prefer the new command for resume/status inspection.
- Keep `refresh-current.sh` and `.context/current.md` intact until the next phase.

## Candidate Files
- `AGENTS.md`
- `README.md`
- `docs/context/RESUME_GUIDE.md`
- `scripts/_lib.sh`
- `scripts/status-task.sh`
- `scripts/refresh-current.sh`
- `tests/smoke.sh`

## Non-goals
- Do not remove `.context/current.md` yet.
- Do not alter local task-selection rules yet.

## Validation
- Operators can get current task status without reading `.context/current.md`.
- Smoke coverage proves the new command is informative enough to replace the dashboard.

## Risks
- A too-thin replacement will force users back into scanning multiple files.

## Exit Criteria
- `status-task.sh` exists and is documented.
- Docs and tests no longer depend on the persisted dashboard as the primary resume surface.
