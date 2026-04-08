# Task: add-improvement-trigger-reporting-rule

> Normal PR rule: one PR should map to one live task file.

## Status
- state: done
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-08 18:31:30Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-08 18:28:57Z
- approval-note: Approved in chat on 2026-04-08 America/Los_Angeles to add concise end-of-task improvement-trigger reporting and require explicit user decision before any improvement work proceeds.

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: the request is one template-process improvement cluster to formalize concise end-of-task improvement-trigger reporting before any new improvement work begins
- bundle-override-approved: no

## Goal
- Add a template rule that when an improvement trigger appears during delivery, the operator reports it briefly at the end of the task and waits for the user to decide whether to discuss, defer, or open a dedicated improvement task.

## Non-goals
- Do not change the checkout-only workflow task that is currently pending publication.
- Do not auto-open improvement tasks or auto-edit the template from metrics or triggers alone.
- Do not add new runtime scripts when documentation and smoke coverage are sufficient.

## Requirements
- RQ-001: Core operator guidance must say that improvement triggers are reported only after the current task work is complete, using a brief summary.
- RQ-002: The template must say that no improvement work starts until the user explicitly decides whether to discuss or proceed.
- RQ-003: The policy must keep improvement triggers advisory rather than automatic, and require a separate improvement task if the user chooses to proceed.
- RQ-004: Smoke coverage must fail if the concise end-of-task reporting guidance disappears from the live template.

## Implementation Plan
- Step 1: Update core operator docs with a brief end-of-task improvement-trigger reporting rule.
- Step 2: Update template-improvement policy and task workflow docs to require explicit user decision before any improvement task begins.
- Step 3: Add smoke assertions so the guidance remains present in the live template and stable mirror.

## Architecture Notes
- intended module boundaries: keep operator behavior rules in `AGENTS.md`, workflow usage notes in `README.md` and `docs/tasks/README.md`, and approval policy in `docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- dependency direction: delivery finishes first, then operator guidance determines whether a concise trigger report is surfaced, and policy decides whether a new improvement task may start
- extraction/refactor triggers in touched files: if post-task reporting guidance grows beyond a few bullets, split template-improvement operations into a dedicated process doc instead of expanding inline sections further

## Target Files
- `AGENTS.md`
- `README.md`
- `docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- `docs/tasks/README.md`
- `tests/smoke.sh`
- `stable-ai-dev-template/AGENTS.md`
- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- `stable-ai-dev-template/docs/tasks/README.md`
- `stable-ai-dev-template/tests/smoke.sh`

## Out of Scope
- Changing task metrics, feedback schemas, or CI gate scripts.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing template-improvement policy and follow-up routing guidance instead of creating a new process surface
- config/constants to centralize: centralize the reporting rule in the existing operator docs rather than scattering it through task-specific notes
- side effects to avoid: avoid implying that triggers automatically authorize improvement work, and avoid mixing this rule into the pending checkout-only task

## Risk Controls
- sensitive areas touched: operator process docs and the mirrored stable template bundle
- extra checks before merge: rerun template sync and smoke after the guidance is added in both root and stable docs

## Acceptance
- The template says improvement triggers are reported briefly at the end of the current task rather than interrupting delivery.
- The template says the user chooses whether to discuss, defer, or proceed with a dedicated improvement task.
- Smoke assertions fail if the end-of-task reporting guidance disappears.

## Verification Commands
- `bash scripts/check-template-sync.sh`
- `bash tests/smoke.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/add-improvement-trigger-reporting-rule/verification.log
- verification-at-utc: 2026-04-08 18:31:00Z

## Review Status
- scope-review-status: pass
- scope-review-note: Scope stayed inside the approved operator docs, policy docs, and smoke coverage.
- scope-review-at-utc: 2026-04-08 18:31:11Z
- quality-review-status: pass
- quality-review-note: The rule keeps improvement triggers advisory, preserves explicit user approval, and adds regression coverage without expanding runtime machinery.
- quality-review-at-utc: 2026-04-08 18:31:18Z
- reuse-review: pass
- hardcoding-review: pass
- tests-review: pass
- request-scope-review: pass
- architecture-review: pass
- risk-controls-review: n/a

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: auto-recover

## Session Resume
- current focus: task completed; ready to publish from the task branch
- next action: If you want this published, create task/add-improvement-trigger-reporting-rule from main and open one PR for the process-doc update.
- known risks: the rule must stay brief enough to be used in final responses, and the stable template mirror must remain identical

## Completion
- summary: Added a rule that improvement triggers are reported briefly at the end of the current task and require explicit user choice before any dedicated improvement work begins.
- follow-up: If you want this published, create task/add-improvement-trigger-reporting-rule from main and open one PR for the process-doc update.
