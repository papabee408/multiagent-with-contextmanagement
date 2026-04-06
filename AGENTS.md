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
3. `docs/context/PROJECT.md` (actual project brief and constraints)
4. `docs/context/ARCHITECTURE.md` (module boundaries)
5. `docs/context/CONVENTIONS.md` (reuse, hardcoding, naming conventions)
6. `docs/context/RULES.md` (implementer coding rules)
7. `docs/context/GATES.md` (pass/fail policy)
8. `test-guide.md` (test-writing style)

If conflicts exist, higher item wins.

## Session Bootstrap (Mandatory)
0. For a new implementation request, classify the feature risk first in `brief.md`:
   - `Standard` (recommended): starts in workflow mode `Lite`
   - `Trivial`: starts in workflow mode `Trivial`
   - `High-Risk`: starts in workflow mode `Full`
   Use the `## Risk Signals` checklist in `brief.md` to justify the route. If one or more signals are `yes`, the feature must be treated as `high-risk` and start in `full`.
   Default execution mode is `Single`.
   Ask the user only when overriding the default workflow route or enabling `Multi-Agent`. `Multi-Agent` may be executed only after the user explicitly chooses it. Once chosen, workflow mode and execution mode are locked until the user explicitly asks to change them.
1. Run `scripts/context-log.sh resume-lite`.
2. Run setup check once when bootstrapping a new project copy:
   - `scripts/check-project-setup.sh`
3. Read first:
   - `docs/context/HANDOFF.md`
   - `docs/context/CODEX_RESUME.md`
4. Load shared docs by role, not all at once:
   - `planner`: `docs/context/PROJECT.md`, `docs/context/ARCHITECTURE.md`, `docs/context/GATES.md`
   - `implementer`: `docs/features/<feature-id>/implementer-handoff.md`, `docs/context/RULES.md`
   - `tester`: `docs/features/<feature-id>/tester-handoff.md`, `docs/features/<feature-id>/test-matrix.md`, `docs/context/GATES.md`, `test-guide.md`
   - `reviewer`: `docs/features/<feature-id>/reviewer-handoff.md`, implementer diff, gate output
   - `security`: implementer diff, relevant config/env usage, `docs/features/<feature-id>/security-handoff.md`
   - `gate-checker`: `docs/features/<feature-id>/plan.md`, `docs/context/GATES.md`
   - `orchestrator`: `docs/context/PROJECT.md`, `docs/context/GATES.md` (state-machine/completion only), `docs/context/HANDOFF.md`, `docs/context/CODEX_RESUME.md`
5. Open deep-dive only when needed:
   - `docs/context/DECISIONS.md`
   - latest `docs/context/sessions/*`
   - `docs/context/DECISIONS_ARCHIVE.md`

## Role Routing Rule (Mandatory)
- Use 7 roles: `orchestrator`, `planner`, `implementer`, `tester`, `gate-checker`, `reviewer`, `security`.
- Context handoff rule:
  - `planner` is the role that reads project intent and architecture deeply.
  - `planner` also reads gate policy deeply so downstream handoffs already include verification expectations.
  - downstream roles should prefer role-specific `*-handoff.md` files as the distilled handoff.
  - downstream roles reopen upstream context docs only when a handoff file is insufficient, contradictory, or missing a required constraint.
- Ownership rule:
  - `brief.md` owns:
    - risk class:
      - `trivial`: lowest-risk route; may default to workflow mode `trivial`
      - `standard`: default route; should start in workflow mode `lite`
      - `high-risk`: requires workflow mode `full`
    - workflow mode:
      - `trivial`: `orchestrator -> planner -> implementer -> gate-checker`
      - `lite`: `trivial` plus `tester`
      - `full`: `lite` plus `reviewer -> security`
    - execution mode:
      - `single`: one lead agent may own multiple roles; bounded helper sub-agents are allowed
      - `multi-agent`: explicit role-level delegation; role `agent-id` values must stay unique
  - `planner` exclusively owns `docs/features/<feature-id>/plan.md` authoring.
  - `planner` refreshes workflow-relevant handoffs by running `scripts/sync-handoffs.sh <feature-id>` after updating `plan.md`.
  - `scripts/sync-handoffs.sh <feature-id>` also re-seeds `docs/features/<feature-id>/test-matrix.md` rows from the RQ list, updates handoff source digests, and removes handoff files that are not required for the active workflow mode.
  - Before dispatching `implementer` in any workflow mode, `bash scripts/gates/check-implementer-ready.sh --feature <feature-id>` must pass; until then code edits are not allowed.
  - `implementer` owns production/source/config edits and the baseline test updates needed for the feature.
  - `tester` never edits production code.
  - `trivial` mode skips `tester`; in that mode `implementer` finalizes `test-matrix.md`.
  - `tester` may strengthen `tests/**` only in `full` mode when implementer coverage is insufficient; in `lite` mode tester should report gaps instead of editing tests.
  - `tester` finalizes `docs/features/<feature-id>/test-matrix.md` before returning `PASS`.
  - `reviewer` is the quality gate in `full` mode and must explicitly judge reuse/componentization, hardcoding/config centralization, and obvious performance waste.
  - `plan.md` owns the implementer execution strategy:
    - `serial`: one implementer agent edits all approved files.
    - `parallel`: parent implementer may dispatch subworkers only across disjoint task-card file sets; parent implementer stays merge owner.
  - `orchestrator` is orchestration-only and must not edit `plan.md`.
- Each role must load only:
  - its own role file in `docs/agents/`
  - current feature packet in `docs/features/<feature-id>/`
  - minimal shared docs required for that role
- Never load all role files at once.
- Runtime guard: if no meaningful progress signal appears within 45s, mark the role `AT_RISK` in `run-log.md` and notify the user.
- Runtime guard: interrupt any role that stays in clarification mode >90s.
- Runtime guard: mark role `BLOCKED` and re-dispatch if no actionable output by 120s.
- Execution integrity:
  - every role output must include `agent-id`
  - in `multi-agent` execution mode, all dispatched role `agent-id` values must be unique
  - in `single` execution mode, the same lead `agent-id` may appear across multiple roles

## Dispatch Visibility Rule (Mandatory)
- Before dispatching a role, orchestrator updates the monitor with:
  - `scripts/dispatch-heartbeat.sh queue --feature <feature-id> <role> "<next action>"`
  - or `scripts/dispatch-role.sh --feature <feature-id> <role> "<next action>"`
- When a role actually starts, update with:
  - `scripts/dispatch-heartbeat.sh start --feature <feature-id> <role> "<first concrete action>"`
- While a role is running, update with:
  - `scripts/dispatch-heartbeat.sh progress|risk|blocked|done --feature <feature-id> <role> "<file/command/blocker>"`
- To write the role output block in `run-log.md`, prefer:
  - `scripts/record-role-result.sh --feature <feature-id> <role> --agent-id <id> --scope "<scope>" --rq-covered "<rq>" --rq-missing "<rq>" --result PASS|FAIL|BLOCKED --evidence "<evidence>" --next-action "<next>" --touched-files "<project files intentionally edited or []>"`
- `touched-files` policy:
  - `orchestrator`: feature/context docs only when non-empty
  - `planner`: current feature packet docs only
  - `implementer`: `plan.md` target files only, plus `docs/features/<feature-id>/test-matrix.md` in `trivial` mode
  - `tester`: `test-matrix.md`, plus `tests/**` only in `full` mode
  - `gate-checker`, `reviewer`, `security`: `[]`
- To finish a role and queue the next one in one step, prefer:
  - `scripts/finish-role.sh --feature <feature-id> <role> "<done message>" --next-role <role> --next-action "<next action>"`
- To inspect the active feature monitor from terminal:
  - `scripts/dispatch-heartbeat.sh show`
- Every role must produce a first meaningful progress signal within 30 seconds.
- Meaningful progress means one of:
  - file(s) being inspected
  - file(s) being edited
  - test command being run
  - gate command being run
  - concrete blocker with next action
- Phrases like "thinking", "checking", or "looking around" are not meaningful progress.
- User waiting rule: keep waiting only when the latest progress update is <=45s old and names a concrete file, command, or blocker.

## Feature Packet Rule (Mandatory)
- Every implementation request maps to one feature packet:
  - `docs/features/<feature-id>/brief.md`
  - `docs/features/<feature-id>/plan.md`
  - `docs/features/<feature-id>/implementer-handoff.md`
  - `docs/features/<feature-id>/test-matrix.md`
  - `docs/features/<feature-id>/run-log.md`
- Mode-specific packet files:
  - `trivial`: no additional handoff files beyond `implementer-handoff.md`
  - `lite`: additionally requires `docs/features/<feature-id>/tester-handoff.md`
  - `full`: additionally requires `docs/features/<feature-id>/tester-handoff.md`, `docs/features/<feature-id>/reviewer-handoff.md`, `docs/features/<feature-id>/security-handoff.md`
- If packet does not exist, create it from `docs/features/_template/`.
- Use `scripts/start-feature.sh <feature-id>` as the only workflow entry.
- To inspect or set workflow mode:
  - `scripts/workflow-mode.sh show --feature <feature-id>`
  - `scripts/workflow-mode.sh role-sequence --feature <feature-id>`
- Before dispatching `implementer`:
  - `bash scripts/gates/check-implementer-ready.sh --feature <feature-id>`
- To inspect or set execution mode:
  - `scripts/execution-mode.sh show --feature <feature-id>`
- To promote a running feature in place:
  - `scripts/promote-workflow.sh --feature <feature-id> <trivial|lite|full> --reason "<why>"`
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
- If the user asks for commit/PR/git cleanup, run `complete-feature.sh` before the final clean-tree check.
- `complete-feature.sh` stages changed closeout files for the active feature and current completion session by default so `run-log.md`, role receipts, and context-log outputs do not leave a false dirty worktree after completion.
- Use `scripts/complete-feature.sh --no-stage-closeout ...` only when the caller explicitly wants those closeout files left unstaged.

## CI Enforcement (Mandatory)
- PR must pass `Gates` workflow.
- `Gates` runs `scripts/gates/run.sh <feature-id>` and fails when any required check fails:
  - `project-context`
  - `brief`
  - `plan`
  - `handoffs`
  - `packet`
  - `role-chain` (including execution-mode `agent-id` rules)
  - `test-matrix`
  - `scope`
  - `file-size`
  - `tests`
  - `secrets`
- Any single FAIL blocks feature completion and PR merge.
- New-project setup alerts must verify:
  - GitHub Actions is enabled.
  - Branch protection requires `Gates` check.
