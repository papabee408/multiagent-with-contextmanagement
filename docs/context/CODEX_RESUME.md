# Codex Resume Snapshot

- Generated At (UTC): 2026-03-27 09:29:23Z
- Primary Next Task: If you want to adopt it, copy the folder into a target repo, customize context docs, and dogfood it on one real feature before replacing the current workflow.
- Latest Session File: docs/context/sessions/20260327-091450-template-v2-minimal-stable.md
- Active Decision Log: docs/context/DECISIONS.md
- Decision Archive: docs/context/DECISIONS_ARCHIVE.md

## Resume Order (New Codex Chat)

1. Read `docs/context/HANDOFF.md`.
2. Read `docs/context/CODEX_RESUME.md`.
3. Open deep-dive files only if needed:
   - `docs/context/DECISIONS.md`
   - latest session file
   - `docs/context/DECISIONS_ARCHIVE.md`

## Current Handoff

# Current Handoff

- Last Updated (UTC): 2026-03-27 09:29:23Z
- Last Session File: docs/context/sessions/20260327-091450-template-v2-minimal-stable.md

## What Was Done
- Added a new stable-ai-dev-template folder with one-task workflow docs, hash-based scope protection, verification receipts, and a passing template-local smoke test.

## Next Task
- If you want to adopt it, copy the folder into a target repo, customize context docs, and dogfood it on one real feature before replacing the current workflow.

## Resume Checklist
- Read `HANDOFF.md` first.
- Read `CODEX_RESUME.md` second.
- Open deep-dive files only when needed.

## Latest Active Decisions (up to 5)

- No active decisions recorded yet.

## Latest Session Excerpt

Source: docs/context/sessions/20260327-091450-template-v2-minimal-stable.md

```text
# Session: template-v2-minimal-stable

- Started At (UTC): 2026-03-27 09:14:50Z
- Status: in_progress

## Goal
- Define the concrete outcome for this session.

## Work Log
- 2026-03-27 09:14:50Z | Session started.
- 2026-03-27 09:19:02Z | Planning stable-ai-dev-template scope, task model, and verification strategy before editing packet docs.
- 2026-03-27 09:20:46Z | Updated template-v2-minimal-stable brief/plan for a smaller single-task template and reran handoff sync.
- 2026-03-27 09:27:48Z | Added stable-ai-dev-template folder with single-task docs, hash-based baseline logic, verification receipts, and a local smoke test.
- 2026-03-27 09:28:46Z | Ran stable-ai-dev-template/tests/smoke.sh successfully after fixing placeholder handling for explicit none values.

## Session Summary
- Added a new stable-ai-dev-template folder with one-task workflow docs, hash-based scope protection, verification receipts, and a passing template-local smoke test.

## Next Step
- If you want to adopt it, copy the folder into a target repo, customize context docs, and dogfood it on one real feature before replacing the current workflow.

- Finished At (UTC): 2026-03-27 09:29:23Z
- Status: completed
```

## Operational Commands

- Start: `scripts/context-log.sh start "<session-title>"`
- Note: `scripts/context-log.sh note "<work-note>"`
- Decision: `scripts/context-log.sh decision "<title>" "<decision>" "<reason>"`
- Archive decisions: `scripts/context-log.sh archive-decisions [keep-count]`
- Monthly maintenance: `scripts/context-log.sh monthly`
- Finish: `scripts/context-log.sh finish "<summary>" "<next-step>"`
