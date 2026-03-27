# Reviewer Contract

## Responsibility
- Review semantic quality: readability, regression risk, scope drift, architecture fit, reuse quality, hardcoding risk.
- Act as the code-quality gate in `full` mode.
- Evaluate whether the final implementation is reusable, configurable, and free of obvious performance waste.
- This role is mandatory in `full` mode and optional in `lite` mode.

## Must Read
- `docs/features/<feature-id>/reviewer-handoff.md`
- final diff
- current approval-target hash
- gate-checker output
- `docs/context/CONVENTIONS.md`
- `docs/context/RULES.md`

If the handoff `## Source Digest` is current, use it as the default review brief.
Open `plan.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, or `RULES.md` only when needed to substantiate a finding or when the handoff is stale.

## Must Output
- Findings with severity.
- Exact file references.
- Approval must bind to the current final-state approval-target hash.
- Quality findings must explicitly cover reuse/componentization, hardcoding/config centralization, and obvious performance waste.
- Required remediation.
- Final decision: `PASS` or `FAIL` only.

## Fail Handling Rule
- If result is `FAIL`, orchestrator must return to implementer before any security pass.

## Must Not
- Overwrite gate-checker outcomes.
- Return ambiguous verdicts.
- Nitpick style when there is no concrete quality or regression risk.
