# Template Upgrade Prompt

Reusable upgrade prompt for integrating this template into an existing repository.

이 파일은 기존 대형 프로젝트에 `context+MultiAgentDev` 템플릿을 안전하게 업그레이드 이식시키기 위한 AI 실행 프롬프트다.

사용 방법:
- 이 폴더를 대상 레포 안에 복사한다.
- 아래 프롬프트 전체를 AI에게 그대로 준다.
- `<TEMPLATE_DIR>`만 실제 경로로 바꿔도 되고, 안 바꾸면 AI가 자동 탐색하게 둬도 된다.

---

You are upgrading an existing repository by integrating a copied multi-agent template with minimal side effects.

Template source directory:
- `<TEMPLATE_DIR>` if provided by the user
- Otherwise, auto-detect the copied template folder by finding a directory that contains:
  - `AGENTS.md`
  - `scripts/gates/run.sh`
  - `scripts/dispatch-heartbeat.sh`
  - `docs/agents/`

Your job is to merge the template into the current repository safely.
Do not treat this as a blind copy task.
Do not stop at analysis.
Inspect the repo, adapt the template to this repo, implement the changes, run verification, and leave a clear summary.

## Goal

Introduce the upgraded template capabilities into this repository:
- better operator visibility via `dispatch-heartbeat`
- stronger gate enforcement for `run-log` and `test-matrix`
- clearer `AGENTS.md` / operator docs
- safer feature-packet based workflow

But do this without breaking the existing project structure, product code, CI, or developer workflow.

## Hard Rules

1. Do not blindly overwrite files just because the template contains them.
2. Do not delete or disable existing CI/workflows unless explicitly asked.
3. Do not rewrite application/product code except where absolutely required to adapt script paths, test commands, or repo-specific integration points.
4. Do not make the new `Gates` workflow a required branch protection check unless the user explicitly asks for that final step.
5. Preserve existing project-specific instructions in `AGENTS.md`, `README.md`, and CI files. Merge carefully.
6. Prefer staged upgrade over full replacement.
7. If the repo already has a workflow, scripts, or docs that overlap in purpose, merge behavior instead of replacing them wholesale.
8. Do not ask broad clarification questions if the answer can be discovered from local files. Inspect first and proceed.

## Required Execution Style

1. First inspect the target repo:
   - repo layout
   - existing `AGENTS.md`
   - existing README / contributor docs
   - existing scripts
   - current test commands
   - CI/workflow files
   - whether `docs/features/` style packet flow already exists
2. Create an upgrade feature packet for this migration work if the repo does not already have one.
3. Adapt the template to the target repo instead of keeping template-only assumptions.
4. Make the changes directly.
5. Run local verification.
6. Summarize what was merged, what was adapted, and what is intentionally left in shadow mode.

## Integration Strategy

Use this order:

### Phase 1: Visibility and operator ergonomics

Bring over and adapt:
- `scripts/dispatch-heartbeat.sh`
- root quick guide / operator docs
- `docs/features/_template/run-log.md`
- `docs/features/_template/test-matrix.md`

Objective:
- operators can inspect current agent status from terminal
- they do not need to manually open `run-log.md` for routine monitoring

### Phase 2: Gate hardening

Bring over and adapt:
- `scripts/gates/check-role-chain.sh`
- `scripts/gates/check-test-matrix.sh`
- `scripts/gates/check-tests.sh`
- `scripts/gates/run.sh`
- related regression tests

Objective:
- local/CI checks fail when `Dispatch Monitor` is incomplete
- local/CI checks fail when `test-matrix.md` is still draft or partially filled

### Phase 3: Docs and role contracts

Merge carefully:
- `AGENTS.md`
- `docs/agents/*`
- `docs/context/GATES.md`
- `docs/features/README.md`
- root `README.md`

Objective:
- the repo explains when to use heartbeat, gates, and feature packets
- agent roles do not allow subjective "PASS override" behavior

### Phase 4: Workflow hookup

Add or adapt:
- `.github/workflows/gates.yml`
- supporting CI helper scripts

Objective:
- the new gate flow can run in CI
- but keep it in shadow mode / non-required mode unless the user explicitly asks to enforce it

## File-by-File Adaptation Rules

### `scripts/gates/check-tests.sh`

Do not keep template example commands if they do not match this repo.
You must inspect the repo and replace them with real commands for this project.

Find likely sources:
- `package.json`
- `Makefile`
- `Justfile`
- `Cargo.toml`
- `pyproject.toml`
- `go.mod`
- existing workflow files
- existing test scripts

Prefer:
- deterministic
- reasonably fast
- repo-native commands

If the project has multiple test layers, choose a practical smoke/unit subset for gates and explain what remains outside the gate.

### `scripts/gates/check-file-size.sh`

Update path globs to match the target repo.
Do not keep template-specific paths like `builder/src/**` if this repo uses something else.

### `scripts/ci/detect-feature.sh`

If the repo can support `docs/features/<feature-id>/`, keep the feature-packet flow.
If the repo already has another structured task/migration folder, adapt detection to that structure rather than forcing a bad fit.
Still keep the rule that one PR should map to one upgrade packet where feasible.

### `AGENTS.md`

Merge, do not replace.
Keep project-specific instructions.
Add the upgraded routing/gate/visibility model only where it does not erase the repo's real constraints.

### `.github/workflows/gates.yml`

Add the workflow if missing, or merge into existing CI if that is cleaner.
Do not delete existing workflows.
Do not make this workflow required unless the user explicitly asks.

## Mandatory Safety Constraints

1. Existing product behavior must not change as a side effect of the template upgrade.
2. Existing tests must not be weakened just to make the upgrade pass.
3. If a copied template script assumes a path that does not exist in this repo, adapt the script. Do not leave dead paths behind.
4. If a template file conflicts with an existing file, prefer merging or renaming over destructive replacement.
5. If a rule is too strict for the target repo's current reality, implement it in a non-blocking or shadow-mode form first and explain why.

## Required Deliverables

By the end of the task, you must leave:

1. A working operator quick-reference document.
2. A working `dispatch-heartbeat` command or equivalent terminal-first monitor.
3. A working `scripts/gates/check-tests.sh` adapted to this repo.
4. A working `scripts/gates/run.sh` path with repo-appropriate checks.
5. Regression tests for the new gate behavior if this repo supports shell/script tests.
6. A clear upgrade packet / migration doc that records:
   - goal
   - scope
   - risks
   - test matrix
   - run log

## Required Verification

You must run all applicable local checks after making changes.

At minimum:
- the repo's adapted gate test command
- the repo's adapted gate runner
- any new regression tests you added

If a check cannot be run locally, say exactly why.

## Final Output Format

Your final summary must include:

1. What you merged directly from the template
2. What you had to adapt for this repo
3. Which parts are still shadow mode / non-required
4. Exact verification commands you ran
5. Residual risks or follow-up items

## Things You Must Not Say

Do not use language like:
- "I will force PASS"
- "I will override FAIL"
- "I will mark it PASS anyway"
- "I will just replace the old template"

Gate results must come from actual command execution, not from judgment.

## Start Now

1. Detect the copied template directory
2. Inspect the target repo
3. Create the upgrade packet
4. Implement the staged merge
5. Run verification
6. Report the result

---

짧게 말하면, 이 작업은 "템플릿 폴더 복붙"이 아니라 "기존 레포에 부작용 적게 업그레이드 이식"이다.
무조건 단계적으로 합치고, repo에 맞게 적응시키고, 마지막에 검증까지 끝내라.
