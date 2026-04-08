# Template Improvement Policy

This file governs changes to the template itself.

## Goal

- Measure friction in the workflow.
- Turn repeated friction into explicit improvement proposals.
- Never auto-edit the template just because a metric exists.

## What To Measure

- objective workflow health
  - completed task count
  - risk-level mix
  - verification pass history
  - review pass history
- optional human feedback
  - requirements fit
  - speed
  - accuracy
  - satisfaction
  - free-form notes

## Where Metrics Live

- local metrics: `.context/template-health/task-metrics.tsv`
- local feedback: `.context/template-health/task-feedback.tsv`

These files are local runtime data. They are not the task contract and should not become merge blockers.

## Improvement Rule

When a report shows recurring friction:

1. summarize the problem in plain language
2. report it briefly at the end of the current task using trigger, impact, and proposal
3. explain tradeoffs and risk if the user wants to discuss it
4. wait for explicit user approval
5. only then open a dedicated template-improvement task

## Hard Rules

- Do not auto-patch the template from metrics alone.
- Do not hide a template change inside a product feature task.
- Do not widen a product task just because the report suggests a workflow fix.
- Do not interrupt the current approved task just because an improvement trigger appears; report it at the end instead.
- If the template itself is the blocker, open a separate stabilization or template-improvement task.
- If a follow-up workflow improvement request arrives after a task is already in `review` or `done`, do not reopen that task; open a dedicated improvement task.
