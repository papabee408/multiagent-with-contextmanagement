# Feature Brief

## Feature ID
- `feature-id`: `template-review-remediation`

## Goal
- Repair the template paths uncovered by code review so a newly bootstrapped project can start cleanly, validate the right documents, and export only reusable assets.

## Non-goals
- Do not redesign the overall role/gate architecture.
- Do not add new workflow stages beyond the existing `lite` multi-agent chain.

## Requirements (RQ)
- `RQ-001`: `scripts/feature-packet.sh` must preserve packet schema keys like `feature-id` instead of rewriting template field names, and a new packet must stay compatible with `check-brief.sh`.
- `RQ-002`: `scripts/gates/check-project-context.sh` must fail when `docs/context/GATES.md` is missing required content or still contains placeholder text.
- `RQ-003`: `scripts/start-feature.sh` must avoid repeating the setup bootstrap check on every new feature after an initial alert-only run.
- `RQ-004`: `scripts/export-template.sh` must exclude repository-specific operational state such as live handoff/resume/status docs and session logs from exported bundles.
- `RQ-005`: Regression tests must cover the above bootstrap, gate, and export behaviors so the failures reproduced in review do not recur.

## Constraints
- Keep the fixes within the template repository's scripts, docs, and shell regression tests.
- Preserve the existing `lite` workflow and `multi-agent` execution contract for this remediation packet.
- Prefer narrow corrections over process expansion; the template should get safer without becoming more complex.

## Acceptance
- A newly created feature packet keeps `brief.md` schema keys intact and can pass `bash scripts/gates/check-brief.sh` once required content is filled.
- `bash scripts/gates/check-project-context.sh` fails on a placeholder `GATES.md` fixture and passes on a real one.
- Repeated `scripts/start-feature.sh` runs do not keep re-running setup alerts forever after the initial bootstrap reminder path.
- `scripts/export-template.sh` output excludes repository-specific operational state files.
- `bash scripts/gates/check-tests.sh --full` passes after the remediation.

## Workflow Mode
- mode: `lite`
- rationale: balanced default path with tester verification and no reviewer/security stage

## Execution Mode
- mode: `multi-agent`
- rationale: independent role ownership or explicit parallel work is worth the coordination overhead

## Requirement Notes
- External dependencies: none beyond the existing optional `gh` CLI project setup check
- Existing modules/components/constants to reuse: existing packet bootstrap scripts, gate helpers, export script, and shell smoke-test patterns
- Values/config that must not be hardcoded: packet schema keys, required context document names, gate-required section names, and exported operational-file exclusion rules
