# Codex Router Prompt

This file is the thin router for this repository.
Do not duplicate detailed role logic here.

## Core Goal
- Keep context small.
- Prevent requirement loss.
- Run work through explicit role contracts.

## Source of Truth
1. `docs/agents/<role>.md` (role behavior)
2. `docs/features/<feature-id>/*` (feature-scoped context)
3. `docs/context/RULES.md` (implementer coding rules)
4. `docs/context/ARCHITECTURE.md` (module boundaries)
5. `docs/context/GATES.md` (pass/fail policy)
6. `test-guide.md` (test-writing style)

If conflicts exist, higher item wins.

## Session Bootstrap (Mandatory)
1. Run `scripts/context-log.sh resume-lite`.
2. Run setup check once when bootstrapping a new project copy:
   - `scripts/check-project-setup.sh`
3. Read first:
   - `docs/context/HANDOFF.md`
   - `docs/context/CODEX_RESUME.md`
4. Open deep-dive only when needed:
   - `docs/context/DECISIONS.md`
   - latest `docs/context/sessions/*`
   - `docs/context/DECISIONS_ARCHIVE.md`

## Role Routing Rule (Mandatory)
- Use 7 roles: `orchestrator`, `planner`, `implementer`, `tester`, `gate-checker`, `reviewer`, `security`.
- Ownership rule:
  - `planner` exclusively owns `docs/features/<feature-id>/plan.md` authoring.
  - `orchestrator` is orchestration-only and must not edit `plan.md`.
- Each role must load only:
  - its own role file in `docs/agents/`
  - current feature packet in `docs/features/<feature-id>/`
  - minimal shared docs required for that role
- Never load all role files at once.
- Runtime guard: interrupt any role that stays in clarification mode >90s.
- Runtime guard: mark role `BLOCKED` and re-dispatch if no actionable output by 120s.
- Multi-agent integrity: every role output must include `agent-id`, and all 7 `agent-id` values must be unique.
- Single-agent reuse across multiple roles is not allowed and must fail gate/CI.

## Feature Packet Rule (Mandatory)
- Every implementation request maps to one feature packet:
  - `docs/features/<feature-id>/brief.md`
  - `docs/features/<feature-id>/plan.md`
  - `docs/features/<feature-id>/test-matrix.md`
  - `docs/features/<feature-id>/run-log.md`
- If packet does not exist, create it from `docs/features/_template/`.
- Use `scripts/start-feature.sh <feature-id>` as the only workflow entry.
- `scripts/set-active-feature.sh <feature-id>` is allowed only for switching an existing packet.

## Context Logging Rule (Mandatory)
- Only orchestrator may run:
  - `scripts/context-log.sh note`
  - `scripts/context-log.sh decision`
  - `scripts/context-log.sh finish`
- Other roles must not write context docs directly.

## End of Request (Mandatory)
- Orchestrator publishes final summary: `RQ covered`, `RQ missing`, key evidence, next action.
- Then run:
  - `scripts/complete-feature.sh <feature-id> "<summary>" "<next-step>"`

## CI Enforcement (Mandatory)
- PR must pass `Gates` workflow.
- `Gates` runs `scripts/gates/run.sh <feature-id>` and fails when:
  - feature packet is missing,
  - role-chain is incomplete,
  - duplicated `agent-id` is detected.
- New-project setup alerts must verify:
  - GitHub Actions is enabled.
  - Branch protection requires `Gates` check.
