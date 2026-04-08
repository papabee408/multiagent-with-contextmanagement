# Feature Plan

## Scope
- target files:
  - `scripts/feature-packet.sh`
  - `scripts/gates/check-project-context.sh`
  - `scripts/start-feature.sh`
  - `scripts/export-template.sh`
  - `scripts/gates/check-tests.sh`
  - `tests/gates.test.sh`
  - `tests/start-feature.test.sh`
  - `tests/export-template.test.sh`
  - `tests/check-tests-modes.test.sh`
  - `tests/gate-cache.test.sh`
- out-of-scope files:
  - `docs/features/template-ops-hardening/*`
  - `docs/features/workflow-speed-and-mode-upgrade/*`
  - application/runtime source outside `scripts/**` and `tests/**`

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 1
- `RQ-003` -> Task 2
- `RQ-004` -> Task 2
- `RQ-005` -> Task 3

## Architecture Notes
- target layer / owning module: shell entrypoint and gate scripts stay in `scripts/`; regression coverage stays in `tests/`; packet and handoff docs remain feature-scoped metadata.
- dependency constraints / forbidden imports: keep the scripts shell-only, avoid introducing runtime-language coupling, and keep export exclusion logic independent from repo-local operational state.
- shared logic or component placement: reuse existing shell helper patterns in `scripts/gates/_helpers.sh` and the current smoke-fixture style in `tests/**`; if exclusion or setup-stamp logic gets repetitive, keep the helper local to the owning script rather than creating a broad shared abstraction.
- risks / assumptions: the bootstrap fix should stop repeated alert loops without changing mode locks, and export exclusions should stay narrow so reusable template docs still ship.

## Reuse and Config Plan
- existing abstractions to reuse: packet/bootstrap shell flow in `scripts/start-feature.sh`, gate parsers in `scripts/gates/_helpers.sh`, and the existing shell smoke-test harnesses.
- extraction candidates for shared component/helper/module: a small local helper for export exclusions in `scripts/export-template.sh`, and a small local helper for setup-check stamp handling in `scripts/start-feature.sh` if the control flow gets noisy.
- constants/config/env to centralize: `feature-id` schema keys, required `GATES.md` sections, the setup-check stamp filename, and the export exclusion list for live handoff/resume/status/session artifacts.
- hardcoded values explicitly allowed: markdown section names required by the gates, the template packet filenames under `docs/features/_template/`, and the specific repo-specific operational files that must be excluded from exported bundles.

## Execution Strategy
- implementer mode: serial
- merge owner: implementer
- shared files reserved for parent:
  - none

## Task Cards
### Task 1
- files:
  - `scripts/feature-packet.sh`
  - `scripts/gates/check-project-context.sh`
  - `tests/gates.test.sh`
- change: preserve packet schema keys during bootstrap and make `GATES.md` validation real instead of existence-only.
- test points:
  - `RQ-001` normal: create a fresh packet, fill the required brief fields, and confirm `check-brief.sh` passes.
  - `RQ-001` error: a packet bootstrap that rewrites `feature-id` or other schema keys must fail the brief gate.
  - `RQ-001` boundary: re-opening an existing packet should keep the original schema keys and not rewrite them again.
  - `RQ-002` normal: a populated `docs/context/GATES.md` passes `check-project-context.sh`.
  - `RQ-002` error: placeholder or empty `GATES.md` content fails `check-project-context.sh`.
  - `RQ-002` boundary: a minimally valid `GATES.md` should still satisfy the content check without requiring unrelated docs changes.
- done when: packet bootstrap stays compatible with `check-brief.sh`, `check-project-context.sh` rejects placeholder `GATES.md` content, and the gate smoke fixture covers both pass and fail paths.

### Task 2
- files:
  - `scripts/start-feature.sh`
  - `scripts/export-template.sh`
  - `tests/start-feature.test.sh`
  - `tests/export-template.test.sh`
- change: stop repeating setup-check alerts after the first bootstrap attempt and exclude repository-specific operational state from exported template bundles.
- test points:
  - `RQ-003` normal: the first bootstrap path records the setup-check result and later `start-feature.sh` invocations do not rerun the setup check indefinitely.
  - `RQ-003` error: a failing setup check should emit the alert once, not on every subsequent feature start.
  - `RQ-003` boundary: an already-bootstrapped feature should still switch active feature state without re-running bootstrap checks.
  - `RQ-004` normal: exported bundles include reusable template content but not live operational files.
  - `RQ-004` error: `HANDOFF.md`, `CODEX_RESUME.md`, `MAINTENANCE_STATUS.md`, and session logs must not leak into the export.
  - `RQ-004` boundary: safe template docs such as `docs/context/DECISIONS.md` and `docs/context/MULTI_AGENT_PROCESS.md` remain exported if they are still part of the reusable template.
- done when: repeated start-feature runs do not keep re-triggering setup alerts, and export output excludes repo-specific operational state while preserving reusable template assets.

### Task 3
- files:
  - `scripts/gates/check-tests.sh`
  - `tests/check-tests-modes.test.sh`
  - `tests/gate-cache.test.sh`
- change: wire the new export regression into the full test runner and keep the mode/cache smoke coverage aligned with the updated infra list.
- test points:
  - `RQ-005` normal: `bash scripts/gates/check-tests.sh --full` runs the new export smoke alongside the existing feature and infra paths.
  - `RQ-005` error: the mode/cache fixtures should fail if the new export smoke is omitted from the infra test list.
  - `RQ-005` boundary: feature-only and infra-only modes should continue to stay separated while still knowing about the new export regression.
- done when: the full regression command includes the export-template smoke path, and both mode/cache fixtures still validate the expected test split after the new file is added.
