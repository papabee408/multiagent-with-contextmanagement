# Codex Context Workflow

Use this flow to survive Codex context resets during long-term development.

## Start of Session

1. Run `scripts/context-log.sh resume-lite`.
2. For a new implementation request, ask the user to choose workflow mode (`Lite`, `Trivial`, `Full`) and execution mode (`Single`, `Multi-Agent`), and present the recommended option first in each question.
3. Read `docs/context/HANDOFF.md` and `docs/context/CODEX_RESUME.md` first.
4. Open deep-dive files only if needed (`DECISIONS.md`, latest session file, `DECISIONS_ARCHIVE.md`).
5. Start a fresh session log:
   `scripts/context-log.sh start "<session-title>"`

## During Session

- Record progress frequently:
  `scripts/context-log.sh note "<what changed>"`
- Record meaningful decisions:
  `scripts/context-log.sh decision "<title>" "<decision>" "<reason>"`

## End of Session

1. Run:
   `scripts/context-log.sh finish "<summary>" "<next-step>"`
2. This also refreshes `docs/context/CODEX_RESUME.md` automatically.

## Monthly Maintenance

1. Run `scripts/context-log.sh monthly`.
2. Review `docs/context/MAINTENANCE_STATUS.md`.
3. If warnings are triggered, archive more decisions or condense old session logs.
