# Feature Plan

## Scope
- target files:
  - `scripts/gates/check-brief.sh`
  - `scripts/dispatch-heartbeat.sh`
  - `tests/gates.test.sh`
  - `tests/dispatch-heartbeat.test.sh`
- out-of-scope files:
  - feature packet workflow scripts unrelated to brief validation or dispatch monitor state handling
  - reviewer/security/full-workflow policy changes beyond the two reviewed findings

## RQ -> Task Mapping
- `RQ-001` -> Task 1: require the `## Risk Signals` section and validate every expected key so deleting the checklist fails `brief` gate.
- `RQ-002` -> Task 2: reset dispatch `started-at-utc` on cross-role `start` and add lifecycle smoke coverage for role handoff timing.

## Architecture Notes
- target layer / owning module: shell gate validation stays in `scripts/gates/check-brief.sh`; dispatch monitor state transitions stay in `scripts/dispatch-heartbeat.sh`; regression coverage stays in shell smoke tests.
- dependency constraints / forbidden imports: keep these fixes in portable shell/perl helpers already used by the repo and avoid introducing app-runtime dependencies.
- shared logic or component placement: reuse current monitor field readers and brief helper functions; if a new condition is needed, extend the existing helper flow instead of duplicating parsing in tests.

## Reuse and Config Plan
- existing abstractions to reuse: `brief_has_risk_signals_section`, `risk_signal_keys`, `monitor_field_value`, and the existing epoch-based dispatch smoke harness.
- extraction candidates for shared component/helper/module: keep the started-at decision in `dispatch-heartbeat.sh` localized unless another monitor transition needs the same branch later.
- constants/config/env to centralize: continue to derive risk-signal keys from `scripts/gates/_helpers.sh` and threshold/timestamps from existing environment variables.
- hardcoded values explicitly allowed: concrete fixture messages and epoch values inside shell smoke tests.

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files:
  - `scripts/gates/check-brief.sh`
  - `tests/gates.test.sh`
- change: make `brief` gate require the risk-signals section and add a failing test case for a brief that omits it.
- done when: deleting `## Risk Signals` causes `check-brief.sh` to fail and the gate smoke test covers that regression.

### Task 2
- files:
  - `scripts/dispatch-heartbeat.sh`
  - `tests/dispatch-heartbeat.test.sh`
- change: reset monitor start time when `start` is called for a different role and add a cross-role lifecycle assertion.
- done when: a new role start records its own start time and the dispatch smoke test proves the reset behavior.
