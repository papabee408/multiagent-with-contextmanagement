# Feature Brief

## Feature ID
- `feature-id`: template-trust-hardening

## Goal
- Strengthen template trust paths so invalid bootstrap requests fail cleanly, stale gate receipts are not reused after relevant test/runtime changes, and setup alerts remain visible until the project is actually configured.

## Non-goals
- Do not redesign the overall workflow model, role chain, or packet schema.
- Do not broaden gate scope beyond the reviewed bootstrap/cache/setup-check paths.
- Do not change already-passing happy-path behavior unless it is required to close the reviewed defects safely.

## Requirements (RQ)
- `RQ-001`: `scripts/feature-packet.sh` must validate user-supplied bootstrap mode/risk inputs before creating a packet or changing `.context/active_feature`, so invalid bootstrap requests leave no partial packet behind.
- `RQ-002`: `scripts/gates/run.sh --reuse-if-valid` must invalidate stale full-gate receipts when infra test files or other gate runtime shell scripts change, while still preserving legitimate cache reuse when inputs are unchanged.
- `RQ-003`: `scripts/start-feature.sh` must keep surfacing project-setup alerts until the setup check passes, so users do not silently miss required GitHub/project configuration work.

## Constraints
- Keep the fix set narrow to the reviewed defects and their direct tests.
- Preserve successful existing flows for valid feature bootstrap, cache reuse on unchanged inputs, and normal feature test receipt reuse.
- Prefer additive validation and fingerprint coverage over broad refactors.

## Acceptance
- Invalid bootstrap inputs fail without creating `docs/features/<feature-id>/` or switching the active feature.
- Full gate cache reuse is blocked when relevant infra test or runtime shell inputs change, and still succeeds when inputs are unchanged.
- Setup-check alerts repeat on subsequent `start-feature.sh` runs until `scripts/check-project-setup.sh` passes.
- Updated shell smoke tests cover the new failure modes and the existing happy paths still pass.

## Risk Signals
- auth-permissions: `no`
- payments-billing: `no`
- data-migration: `no`
- public-api: `no`
- infra-deploy: `no`
- secrets-sensitive-data: `no`
- blast-radius: `yes`
- note: switch one or more items to `yes` when the request touches that area deeply enough to justify `high-risk -> full`

## Risk Class
- class: `high-risk`
- rationale: the fixes touch shared bootstrap and gate-cache paths used by every feature packet, so a regression would affect the entire template workflow.

## Workflow Mode
- mode: `full`
- rationale: higher-risk change keeps reviewer and security required from the start

## Execution Mode
- mode: `single`
- rationale: one lead agent owns the feature end-to-end; helper sub-agents stay optional and bounded

## Requirement Notes
- External dependencies: none beyond the existing shell, git, node, and sha tooling already assumed by the template.
- Existing modules/components/constants to reuse: existing shell helpers in `scripts/gates/_helpers.sh` and `_validation_cache.sh`, plus the current smoke-test harnesses in `tests/*.test.sh`.
- Values/config that must not be hardcoded: accepted risk/workflow/execution mode tokens, the setup stamp path, and any file lists that define cache invalidation coverage.
