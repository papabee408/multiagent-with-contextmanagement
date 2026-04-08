# Context Maintenance Status

- Generated At (UTC): 2026-03-27 09:29:25Z
- Session Files: 16
- Context Size (KB): 156
- Active Decisions: 0
- Archived Decisions: 0

## Threshold Checks

- Session file threshold (300): ok
- Context size threshold in KB (4096): ok

## Workflow KPIs

- Feature packets: 11
- Workflow overrides: 2/11 (18.2%)
- High-risk compliance: 3/3 (100.0%)
- Full gate PASS coverage: 10/11 (90.9%)
- Average planner-to-gate-checker minutes: 12.1 (samples: 10)

### Risk Mix
- trivial: 0 (0.0%)
- standard: 5 (45.5%)
- high-risk: 3 (27.3%)

### Workflow Mix
- trivial: 0 (0.0%)
- lite: 6 (54.5%)
- full: 5 (45.5%)

### Execution Mix
- single: 9 (81.8%)
- multi-agent: 1 (9.1%)

### Target Bands
- trivial: target 10.0%, actual 0.0%
- lite: target 75.0%, actual 54.5%
- full: target 15.0%, actual 45.5%

### Attention
- high-risk-missing-full: 0
- standard-or-trivial-in-full: 2
- full-gate-fail: 0
- packets-without-pass-full-gate: 1

## Next Actions

- If either threshold is warning, run `scripts/context-log.sh archive-decisions` with a lower keep count and tighten note verbosity.
- Review the workflow KPI mix before changing default routing or reviewer/security policy.
- Keep startup reading focused on `HANDOFF.md` and `CODEX_RESUME.md`.
