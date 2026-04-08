# Feature Plan

## Scope
- target files:
  - `AGENTS.md`
  - `README.md`
  - `docs/agents/README.md`
  - `docs/agents/orchestrator.md`
  - `docs/context/CODEX_WORKFLOW.md`
  - `docs/context/GATES.md`
  - `docs/context/MAINTENANCE.md`
  - `docs/features/README.md`
  - `docs/features/_template/brief.md`
  - `scripts/context-log.sh`
  - `scripts/feature-packet.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-brief.sh`
  - `scripts/gates/check-tests.sh`
  - `scripts/report-template-kpis.sh`
  - `tests/context-log.test.sh`
  - `tests/check-tests-modes.test.sh`
  - `tests/gate-cache.test.sh`
  - `tests/gates.test.sh`
  - `tests/report-template-kpis.test.sh`
  - `tests/start-feature.test.sh`
- out-of-scope files:
  - dispatch runtime enforcement from stage 2
  - reviewer/security approval binding mechanics
  - feature-gate cache internals beyond KPI reporting that reads their existing receipts

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2
- `RQ-003` -> Task 2
- `RQ-004` -> Task 3

## Architecture Notes
- target layer / owning module: brief/risk parsing remains in shell helper + gate scripts; KPI aggregation lives in a standalone shell script and is consumed by monthly maintenance output; operator docs mirror those contracts.
- dependency constraints / forbidden imports: no external telemetry or service dependencies; keep parsing shell-native and fixture-friendly; do not make old feature packets fail just because they predate the risk checklist section.
- shared logic or component placement: risk signal parsing should be centralized in `scripts/gates/_helpers.sh`; monthly maintenance should call the KPI script rather than reimplement its aggregation logic inline.

## Reuse and Config Plan
- existing abstractions to reuse: brief section parsers in `check-brief.sh`, mode defaults in `_helpers.sh`, maintenance status generation in `scripts/context-log.sh`, receipt timestamps already written by role/gate artifacts
- extraction candidates for shared component/helper/module: centralize risk-signal parsing helpers and KPI target-band constants instead of duplicating them across docs, gates, and reports
- constants/config/env to centralize: risk-signal keys, workflow target bands (`trivial 10`, `lite 75`, `full 15`), KPI report labels, completion timestamp selection rules
- hardcoded values explicitly allowed: markdown section names in `brief.md` and `MAINTENANCE_STATUS.md`, deterministic fixture timestamps in shell tests

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files: `docs/features/_template/brief.md`, `scripts/gates/_helpers.sh`, `scripts/gates/check-brief.sh`, `scripts/feature-packet.sh`, `AGENTS.md`, `docs/agents/README.md`, `docs/agents/orchestrator.md`, `docs/features/README.md`, `README.md`, `docs/context/CODEX_WORKFLOW.md`, `docs/context/GATES.md`
- change: add a structured risk-signal checklist, parse it centrally, enforce contradictions in brief validation, and document the new stage-3 routing criteria consistently across operator docs
- done when: new feature briefs seed concrete risk-signal fields, high-risk signals require `high-risk -> full`, and the surrounding docs all describe the same default/override behavior

### Task 2
- files: `scripts/report-template-kpis.sh`, `scripts/context-log.sh`, `docs/context/MAINTENANCE.md`
- change: add a reusable KPI report for workflow/risk operations and embed its summary into monthly maintenance output with target-band guidance
- done when: operators can run one command to see workflow mix, override rate, full-gate coverage, and execution span, and monthly maintenance includes that same KPI block

### Task 3
- files: `tests/context-log.test.sh`, `tests/check-tests-modes.test.sh`, `tests/gate-cache.test.sh`, `tests/gates.test.sh`, `tests/report-template-kpis.test.sh`, `tests/start-feature.test.sh`, `scripts/gates/check-tests.sh`
- change: add deterministic regression coverage for the risk checklist, KPI reporting, and monthly maintenance integration
- done when: targeted shell tests and the authoritative full gate pass without making the default route heavier
