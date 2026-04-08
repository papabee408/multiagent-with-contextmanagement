# Context Logging Guide

This folder keeps durable project memory so development can continue after any context reset.

## File Roles

- `PROJECT.md`: Stable project brief (goal, stack, conventions).
- `CONVENTIONS.md`: Reuse, hardcoding, naming, and review conventions.
- `HANDOFF.md`: Latest checkpoint for next session.
- `DECISIONS.md`: Active architecture and policy decisions.
- `DECISIONS_ARCHIVE.md`: Archived historical decisions.
- `CODEX_WORKFLOW.md`: Codex session operating guide.
- `MAINTENANCE.md`: Monthly maintenance routine and thresholds.
- `MAINTENANCE_STATUS.md`: Latest maintenance metrics snapshot.
- `CODEX_RESUME.md`: Compact snapshot for context-reset recovery.
- `sessions/*.md`: Chronological session logs.

## Daily Workflow

1. `scripts/context-log.sh start "<title>"`
2. `scripts/context-log.sh note "<what changed>"` (keep notes concise)
3. `scripts/context-log.sh decision "<title>" "<decision>" "<reason>"` (optional)
4. `scripts/context-log.sh finish "<summary>" "<next-step>"`
5. (Optional) `scripts/context-log.sh snapshot`

## Monthly Workflow

1. `scripts/context-log.sh monthly`
2. Review `docs/context/MAINTENANCE_STATUS.md`
3. If warnings are triggered, archive additional decisions or compress old session notes.

## Codex Resume Workflow

1. Run `scripts/context-log.sh resume-lite`.
2. Read `HANDOFF.md` + `CODEX_RESUME.md` first.
3. Open deep-dive files only when needed.
