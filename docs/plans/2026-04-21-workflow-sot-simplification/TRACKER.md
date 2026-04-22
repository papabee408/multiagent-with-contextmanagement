# Workflow SoT Simplification Rollout

## Objective
- Simplify the workflow so `docs/tasks/<task-id>.md` becomes the canonical workflow record, while duplicated runtime state and overlapping rule ownership are reduced without regressing operator usability, CI safety, or stale-review protection.

## Preserved Quality Bar
- Explicit approval and `start-task` remain required before implementation.
- Clean-start and `publish-late` safety rules remain enforced.
- Scope remains machine-checked against the approved task contract.
- Verification commands still run from the task file.
- Review still becomes stale when the contract or scoped diff changes.
- CI task resolution becomes narrower, but only through tested compatibility steps.

## Rollout Order
1. [Phase 1: CI Resolver Hardening](./PHASE-01-ci-resolver-hardening.md)
2. [Phase 2: Ownership Doc Alignment](./PHASE-02-ownership-doc-alignment.md)
3. [Phase 3: Status Command Introduction](./PHASE-03-status-command-introduction.md)
4. [Phase 4: Persisted Dashboard Removal](./PHASE-04-persisted-dashboard-removal.md)
5. [Phase 5: Validator And Doc Dedupe](./PHASE-05-validator-and-doc-dedupe.md)
6. [Phase 6: Freshness Dual-Write, Gate Switch, And Receipt Retirement](./PHASE-06-freshness-dual-write-gate-switch-and-receipt-retirement.md)
7. [Phase 7: PR Cache Dependency Removal](./PHASE-07-pr-cache-dependency-removal.md)
8. [Phase 8: Local Task Pointer Policy](./PHASE-08-local-task-pointer-policy.md)

## Why This Order
- CI split-brain is reduced before any local workflow surface is removed.
- A replacement status surface exists before the persisted dashboard is removed.
- Validator dedupe happens before freshness migration, but without touching review semantics.
- Freshness migration uses an explicit compatibility window instead of a cutover by prose.
- `pr.env` and `.context/active_task` are handled separately because they are different risk domains.

## Phase Compatibility And Rollback
| Phase | Compatibility Window | Rollback Path |
| --- | --- | --- |
| 1 | Keep PR body `Task-ID` as a compatibility resolver while removing `.context/active_task` from CI. | Restore previous resolver order and smoke scenarios. |
| 2 | Docs-only phase; no behavior change required. | Restore previous wording if contradictions appear. |
| 3 | `status-task` and persisted dashboard coexist. | Keep using `refresh-current.sh` and restore docs/tests to dashboard path. |
| 4 | `refresh-current.sh` may remain as a compatibility wrapper, but no script should write `.context/current.md`. | Re-enable persisted dashboard writes temporarily. |
| 5 | Keep current `review-scope` and review fields intact while deduping authority. | Restore previous doc text or CI-local duplication if needed. |
| 6 | Dual-write receipts and tracked freshness until gates, reporting, and validators accept both. | Keep receipt files authoritative and continue dual-write. |
| 7 | Cache may remain optional during transition, but publish/land must not require it. | Re-enable cache reads while keeping direct lookup path. |
| 8 | `.context/active_task` may be demoted before removal; removal is conditional on UX safety. | Keep the file as a non-authoritative compatibility shim. |

## Cross-Phase Preconditions
- Before any tracked review field is removed or redefined, validators and generators must support both legacy and new task schemas.
- Every phase must leave smoke coverage green before the next phase starts.
- If a phase reveals hidden coupling that materially changes rollout shape, update these plan files before continuing.

## Out Of Scope For This Rollout
- Telemetry and helper-script deletion that does not directly affect source-of-truth boundaries.
- Broad stylistic doc cleanup beyond what is needed to remove contradictory authority.
- Removing optional convenience surfaces solely for aesthetic reasons.

## Success Criteria
- The task file is the only canonical answer to task state and merge-readiness fields.
- CI identifies the task without consulting local runtime state.
- Runtime files are either optional helpers or removed.
- Operator resume/status remains cheap and explicit.
- Remaining docs and scripts have non-overlapping ownership.
