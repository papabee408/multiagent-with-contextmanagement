# Feature Brief

## Feature ID
- `feature-id`: template-stage3-operations

## Goal
- Turn the template's operating model into something measurable: explicit high-risk routing criteria, a reusable KPI report, and monthly maintenance output that shows whether the fast default path is actually holding.

## Non-goals
- Do not add new mandatory runtime roles or make the default `standard -> lite -> single` route heavier.
- Do not attempt natural-language auto-classification of risk from arbitrary user requests; stage 3 only formalizes operator-visible risk signals and reporting.

## Requirements (RQ)
- `RQ-001`: `brief.md` and brief validation must support an explicit risk-signal checklist so high-risk routing is backed by concrete yes/no criteria instead of free-form rationale only.
- `RQ-002`: The template must ship a KPI/reporting command that summarizes feature packet workflow mix, risk mix, workflow overrides, high-risk compliance, full-gate coverage, and average execution span from existing packet artifacts.
- `RQ-003`: Monthly maintenance output and operator docs must surface those workflow KPIs together with target bands so the team can tell whether `lite`, `full`, and override usage are drifting.
- `RQ-004`: Stage-3 docs, packet templates, and regression coverage must stay aligned with the current default operating contract (`standard -> lite -> single`, `high-risk -> full`, explicit opt-in for `multi-agent`).

## Constraints
- Keep the KPI report shell-native and repository-local; do not add external services, databases, or telemetry dependencies.
- Preserve backward compatibility for existing feature packets that do not yet contain the new risk-signal checklist.
- Keep the report deterministic so shell smoke tests can validate it with fixed fixtures.

## Acceptance
- New briefs expose a concrete risk-signal checklist and `check-brief.sh` enforces contradictions between those signals and the chosen risk/workflow route.
- A standalone KPI script reports workflow/risk distribution, override counts, target-band comparison, and execution span from feature packet artifacts.
- `scripts/context-log.sh monthly` writes maintenance status that includes the workflow KPI section.
- Targeted regression tests and authoritative full gates pass for the stage-3 packet.

## Risk Class
- class: `standard`
- rationale: default product work keeps tester verification while avoiding reviewer/security overhead

## Workflow Mode
- mode: `lite`
- rationale: balanced default path with tester verification and no reviewer/security stage

## Execution Mode
- mode: `single`
- rationale: one lead agent owns the feature end-to-end; helper sub-agents stay optional and bounded

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: `default_workflow_mode_for_risk_class` and other brief parsing helpers in `scripts/gates/_helpers.sh`, feature packet artifacts already written by role/gate scripts, monthly maintenance generation in `scripts/context-log.sh`
- Values/config that must not be hardcoded: risk-signal keys, target workflow bands, workflow/risk mode names, KPI field names, role receipt timestamp semantics
