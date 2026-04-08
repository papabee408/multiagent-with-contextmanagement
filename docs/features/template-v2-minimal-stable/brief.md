# Feature Brief

## Feature ID
- `feature-id`: template-v2-minimal-stable

## Goal
- Create a new copyable template folder that keeps long-lived AI development stable across context resets while staying smaller, stricter, and easier to trust than the current workflow engine.

## Non-goals
- Do not replace or mutate the existing multi-agent template in this change.
- Do not add a new role-state machine, generated handoff graph, or cache reuse layer to the new template.
- Do not redesign unrelated product/UI code outside the new template folder.

## Requirements (RQ)
- `RQ-001`: Provide a self-contained template folder that gives a new AI session enough durable context to resume work quickly without reading the entire repository.
- `RQ-002`: Provide a single-task workflow that constrains edits to request-approved files and explicitly discourages unrelated UI/design churn.
- `RQ-003`: Provide fail-closed verification scripts for context validity, task completeness, scope checking, test execution receipts, and task completion freshness.
- `RQ-004`: Provide usage guidance and a template-local smoke test that proves the new template handles dirty-worktree baselines and stale verification receipts safely.

## Constraints
- The new template must live under one new root folder and be copyable into another repository without depending on the current repo's feature-packet engine.
- Runtime state should stay small: one active-task pointer, one task contract file per request, one current snapshot, and one decision log.
- Scope and verification freshness must use content hashes, not path-only baseline snapshots.
- Scripts should rely on Bash, Git, and standard hash tools already available in this repository.

## Acceptance
- A user can copy the new folder, customize context docs, bootstrap a task, run scoped checks, record verification, refresh the resume snapshot, and complete a task using only the provided scripts.
- The new template documents its source-of-truth order, task lifecycle, and deliberate exclusions from the old design.
- The smoke test demonstrates that unchanged pre-existing dirty files are ignored, later edits to those same files are caught, and stale verification receipts are rejected.

## Risk Signals
- auth-permissions: `no`
- payments-billing: `no`
- data-migration: `no`
- public-api: `no`
- infra-deploy: `no`
- secrets-sensitive-data: `no`
- blast-radius: `no`
- note: switch one or more items to `yes` when the request touches that area deeply enough to justify `high-risk -> full`

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
- External dependencies: Bash, Git, and a SHA-256 tool already expected in local development environments
- Existing modules/components/constants to reuse: reuse only general shell patterns from this repository; keep the new template itself standalone and small
- Values/config that must not be hardcoded: active task identifiers, baseline digests, verification freshness fingerprints, and allowed target-file lists must come from task/runtime state rather than scattered literals
