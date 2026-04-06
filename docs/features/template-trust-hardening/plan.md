# Feature Plan

## Scope
- target files:
  - `scripts/feature-packet.sh`
  - `scripts/start-feature.sh`
  - `scripts/gates/_validation_cache.sh`
  - `scripts/gates/run.sh`
  - `tests/start-feature.test.sh`
  - `tests/gate-cache.test.sh`
- out-of-scope files:
  - unrelated workflow docs, role contracts, and gate scripts outside the reviewed bootstrap/cache/setup-check paths
  - feature packet schema changes beyond the minimum required for these trust fixes
  - new workflow modes, new role types, or broad caching redesign

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2
- `RQ-003` -> Task 3

## Architecture Notes
- target layer / owning module: bootstrap entrypoints stay in `scripts/`; validation-cache behavior stays in `scripts/gates/_validation_cache.sh`; regression coverage stays in the existing shell smoke tests under `tests/`.
- dependency constraints / forbidden imports: keep shell-only behavior with no new runtime dependencies; do not change packet layout or gate command shapes; preserve compatibility with current `scripts/gates/run.sh` and `scripts/start-feature.sh` entrypoints.
- shared logic or component placement: extend existing local helpers where possible instead of introducing a new subsystem; cache input coverage belongs in `_validation_cache.sh`.

## Reuse and Config Plan
- existing abstractions to reuse: current mode/token validation flow in `scripts/feature-packet.sh`, fingerprint helpers in `_validation_cache.sh`, and the existing smoke-test fixture patterns in `tests/start-feature.test.sh` and `tests/gate-cache.test.sh`.
- extraction candidates for shared component/helper/module: only extract a small local prevalidation helper in `scripts/feature-packet.sh` if it keeps the bootstrap path clearer; otherwise keep changes inline and minimal.
- constants/config/env to centralize: cache input file lists and setup-stamp handling should stay in one place rather than being redefined across scripts/tests.
- hardcoded values explicitly allowed: the reviewed script/test filenames and existing mode tokens already required by the template contract.

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files:
  - `scripts/feature-packet.sh`
  - `tests/start-feature.test.sh`
- change: add bootstrap prevalidation so invalid risk/workflow/execution inputs fail before packet creation or active-feature mutation, and cover the no-partial-state behavior with a regression test.
- done when: invalid bootstrap inputs leave no new feature directory, no active-feature switch, and valid bootstrap flows still pass the existing smoke coverage.

### Task 2
- files:
  - `scripts/gates/_validation_cache.sh`
  - `scripts/gates/run.sh`
  - `tests/gate-cache.test.sh`
- change: widen full-gate cache invalidation to cover infra shell tests and root shell runtime scripts, and require the stored feature-test fingerprint to match before full-gate reuse.
- done when: unchanged inputs still reuse the PASS receipt, but committed infra test/runtime shell changes force `--reuse-if-valid` to rerun the gate instead of reusing stale PASS output.

### Task 3
- files:
  - `scripts/start-feature.sh`
  - `tests/start-feature.test.sh`
- change: keep project setup alerts visible by stamping only successful setup checks, and update the smoke test to prove alerting runs are retried until the check passes.
- done when: repeated `start-feature.sh` calls continue to surface setup alerts until `scripts/check-project-setup.sh` succeeds, without breaking valid feature bootstrap.
