# Feature Plan

## Scope
- target files:
  - `AGENTS.md`
  - `docs/agents/orchestrator.md`
  - `docs/agents/reviewer.md`
  - `docs/agents/security.md`
  - `docs/context/GATES.md`
  - `docs/features/_template/brief.md`
  - `scripts/feature-packet.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-brief.sh`
  - `scripts/gates/check-handoffs.sh`
  - `scripts/gates/check-packet.sh`
  - `scripts/gates/check-role-chain.sh`
  - `scripts/start-feature.sh`
  - `scripts/sync-handoffs.sh`
  - `tests/gates.test.sh`
  - `tests/start-feature.test.sh`
- out-of-scope files:
  - unrelated template remediation work already staged in other feature packets
  - runtime guard automation and test-command generalization beyond the bootstrap/routing changes in this stage

## RQ -> Task Mapping
- `RQ-001` -> Task 1: change bootstrap defaults and brief parsing to route by risk class instead of requiring explicit mode selection each time
- `RQ-002` -> Task 2: make packet and handoff generation workflow-aware so only relevant artifacts exist for the chosen mode
- `RQ-003` -> Task 3: align role docs, gate policy, and smoke tests with the new default operating model

## Architecture Notes
- target layer / owning module: routing and packet policy stay in `AGENTS.md`, `docs/agents/*`, `scripts/feature-packet.sh`, `scripts/start-feature.sh`, and the gate helpers under `scripts/gates/`
- dependency constraints / forbidden imports: keep the change within shell/docs/test layers; do not add app-runtime dependencies or bypass the existing helper parsing conventions
- shared logic or component placement: shared brief parsing and workflow/risk normalization belongs in `scripts/gates/_helpers.sh`; workflow-aware handoff generation stays centralized in `scripts/sync-handoffs.sh`

## Reuse and Config Plan
- existing abstractions to reuse: `workflow_mode_from_brief`, `execution_mode_from_brief`, packet bootstrap scripts, and current smoke-test fixture helpers
- extraction candidates for shared component/helper/module: add risk-class parsing/routing helpers to `_helpers.sh` instead of duplicating logic across gate scripts and bootstrap scripts
- constants/config/env to centralize: valid risk classes, default workflow/execution modes, and workflow-specific required handoff files
- hardcoded values explicitly allowed: the three risk classes (`trivial`, `standard`, `high-risk`) and the mode names already enforced by the template contract

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files:
  - `AGENTS.md`
  - `docs/agents/orchestrator.md`
  - `docs/context/GATES.md`
  - `docs/features/_template/brief.md`
  - `scripts/feature-packet.sh`
  - `scripts/gates/_helpers.sh`
  - `scripts/gates/check-brief.sh`
  - `scripts/start-feature.sh`
- change: introduce `Risk Class`, define `lite + single` as the default bootstrap route, and make `high-risk` start in `full` without asking for mode selection on every request
- done when:
  - brief templates and parsing require a non-placeholder risk class
  - new packets derive workflow defaults from risk class
  - docs and gate policy describe the same default/bootstrap behavior

### Task 2
- files:
  - `scripts/feature-packet.sh`
  - `scripts/gates/check-handoffs.sh`
  - `scripts/gates/check-packet.sh`
  - `scripts/sync-handoffs.sh`
- change: generate and validate only the handoff files required for the active workflow mode so `trivial`/`lite` work does not carry reviewer/security packet overhead
- done when:
  - `trivial` packets require only implementer handoff
  - `lite` packets require implementer and tester handoffs
  - `full` packets additionally require reviewer and security handoffs

### Task 3
- files:
  - `docs/agents/reviewer.md`
  - `docs/agents/security.md`
  - `scripts/gates/check-role-chain.sh`
  - `tests/gates.test.sh`
  - `tests/start-feature.test.sh`
- change: remove doc/gate contradictions around reviewer/security in `lite` mode and update smoke coverage for risk-based defaults and workflow-aware packet files
- done when:
  - reviewer/security contracts only describe `full` workflow ownership by default
  - placeholder-only reviewer/security sections in `run-log.md` do not block `lite` or `trivial` role-chain validation
  - smoke tests cover `standard -> lite`, `high-risk -> full`, and optional handoff files by mode
