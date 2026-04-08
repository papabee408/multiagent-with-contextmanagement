# Context Maintenance

Run this routine once per month to keep startup context lightweight.

## Monthly Command

- Run: `scripts/context-log.sh monthly`
- Output: `docs/context/MAINTENANCE_STATUS.md`

## What Monthly Does

1. Archives old decisions from `DECISIONS.md` into `DECISIONS_ARCHIVE.md`, keeping the latest 40 active entries.
2. Regenerates `CODEX_RESUME.md`.
3. Captures current context metrics and workflow KPI summary in `MAINTENANCE_STATUS.md`.

## Warning Thresholds

- Session files warning: more than 300 files in `docs/context/sessions`
- Context size warning: more than 4096 KB for `docs/context`

If warnings trigger, tighten note verbosity and archive decisions sooner.

## Workflow KPI Targets

- `trivial`: around 10%
- `lite`: around 75%
- `full`: around 15%

Monthly review should also look for:
- rising workflow override rate
- `high-risk` requests that are not in `full`
- too many `standard` features ending up in `full`
