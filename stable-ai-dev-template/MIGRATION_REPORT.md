# Migration Report

## Phase
- phase: 0 discovery only
- generated-at-utc: 2026-04-08 00:27:19Z
- repository: papabee408/multiagent-with-contextmanagement
- local-branch: main
- worktree-status: clean
- recommendation: ready for phase-1 cutover after explicit approval

## Discovery Summary
- The repository root is still running the old multi-agent packet workflow.
- `stable-ai-dev-template/` is already present as the newest tracked template bundle.
- `codex-template-multi-agent-process/` exists as an ignored export bundle and can be regenerated later.
- The safest migration path is archive-first cutover, not blind delete-and-replace.

## Old Template Markers Found
- `.github/workflows/gates.yml`
- `scripts/gates/run.sh`
- `scripts/start-feature.sh`
- `scripts/complete-feature.sh`
- `scripts/workflow-mode.sh`
- `scripts/execution-mode.sh`
- `scripts/promote-workflow.sh`
- `scripts/sync-handoffs.sh`
- `docs/features/_template/`
- `docs/agents/` with 8 tracked role files
- `docs/context/HANDOFF.md`
- `docs/context/CODEX_RESUME.md`
- `docs/context/GATES.md`
- `docs/context/MULTI_AGENT_PROCESS.md`
- `.context/active_feature`
- `.context/active_session`

## Current CI / Workflow State
- GitHub default branch: `main`
- Local branch: `main`
- Active GitHub workflow count: 1
- Active workflow name: `Gates`
- Active workflow path: `.github/workflows/gates.yml`
- `main` branch protection: disabled (`protected=false`)
- Repository rulesets: none
- Current CI gate entrypoint: `scripts/gates/run.sh`
- Current stable-template smoke path: `stable-ai-dev-template/tests/smoke.sh`

## Unfinished Old Packet Status
- `.context/active_feature` points to `template-v2-minimal-stable`
- `docs/features/template-v2-minimal-stable/brief.md` and `docs/context/CODEX_RESUME.md` describe that work as completed on 2026-03-27
- `docs/features/template-v2-minimal-stable/run-log.md` has no live dispatch state
- `docs/features/` currently contains `_template` plus 11 historical packet directories
- assessment: this is a stale active pointer, not a real in-flight implementation
- recommended handling: freeze and archive the old packet state; do not convert it into a live task

## File Collisions

### Merge-Required Root Collisions
- `.gitignore`
- `AGENTS.md`
- `README.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/CONVENTIONS.md`
- `docs/context/DECISIONS.md`
- `docs/context/PROJECT.md`
- `test-guide.md`

### Direct-Add Or Direct-Replace Candidates
- `.github/workflows/ai-gate.yml`
- `docs/tasks/README.md`
- `docs/tasks/_template.md`
- `docs/context/CURRENT.md`
- `docs/context/CI_PROFILE.md`
- `docs/context/TEMPLATE_IMPROVEMENT_POLICY.md`
- `scripts/_lib.sh`
- `scripts/approve-task.sh`
- `scripts/bootstrap-task.sh`
- `scripts/check-context.sh`
- `scripts/check-scope.sh`
- `scripts/check-task.sh`
- `scripts/ci/project-checks.sh`
- `scripts/ci/run-ai-gate.sh`
- `scripts/complete-task.sh`
- `scripts/log-decision.sh`
- `scripts/merge-task-pr.sh`
- `scripts/open-task-pr.sh`
- `scripts/record-task-feedback.sh`
- `scripts/record-task-metrics.sh`
- `scripts/refresh-current.sh`
- `scripts/report-template-health.sh`
- `scripts/review-independent.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `scripts/setup-ci-profile.sh`
- `scripts/start-task.sh`
- `scripts/submit-task-plan.sh`

### Archive-Or-Remove Targets After Cutover
- `.github/workflows/gates.yml`
- `scripts/gates/` with 16 gate files
- `scripts/start-feature.sh`
- `scripts/complete-feature.sh`
- `scripts/workflow-mode.sh`
- `scripts/execution-mode.sh`
- `scripts/promote-workflow.sh`
- `scripts/sync-handoffs.sh`
- `scripts/dispatch-heartbeat.sh`
- `scripts/dispatch-role.sh`
- `scripts/record-role-result.sh`
- `scripts/finish-role.sh`
- `scripts/context-log.sh`
- `scripts/feature-packet.sh`
- `scripts/implementer-subtasks.sh`
- `scripts/check-project-setup.sh`
- `scripts/export-template.sh`
- `scripts/report-template-kpis.sh`
- `scripts/set-active-feature.sh`
- `scripts/stage-closeout.sh`
- `docs/features/`
- `docs/agents/`
- `docs/context/HANDOFF.md`
- `docs/context/CODEX_RESUME.md`
- `docs/context/GATES.md`
- `docs/context/MAINTENANCE.md`
- `docs/context/MAINTENANCE_STATUS.md`
- `docs/context/MULTI_AGENT_PROCESS.md`
- `.context/active_feature`
- `.context/active_session`
- `codex-template-multi-agent-process/`

## Proposed CI Profile First Pass

```md
# CI Profile

## Project Profile
- platform: backend
- stack: shell-template
- package-manager: none
- setup-status: manual-review-required

## Git / PR Policy
- git-host: github
- default-base-branch: main
- default-branch-strategy: publish-late
- task-branch-pattern: task/<task-id>
- required-check-resolution: branch-protection-first
- merge-method: squash

## Required Check Fallback
- `AI Gate`

## PR Fast Checks
- `bash tests/smoke.sh`

## High-Risk Checks
- `bash tests/smoke.sh`

## Full Project Checks
- `bash tests/smoke.sh`

## Notes
- Adapt `stable-ai-dev-template/tests/smoke.sh` into a root-level `tests/smoke.sh` during phase 1 instead of keeping CI pointed at the nested bundle.
- Do not keep old `node --test tests/unit/*.test.mjs` and `bash tests/*.test.sh` as live required checks after the old packet workflow is archived.
- `setup-ci-profile.sh` auto-detection will not classify this repository cleanly because it is a shell-driven template repo with no package manifest.
```

## Proposed Cutover Method
- Create migration branch `chore/migrate-stable-ai-template`
- Create rollback tag `before-stable-ai-template-migration`
- Install the new root task-driven runtime files from the bundle
- Rewrite root `AGENTS.md` to the stable task-driven instructions
- Rewrite root `README.md` as a root template guide instead of copying the nested bundle README verbatim
- Merge repository-specific content into `docs/context/PROJECT.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, and `DECISIONS.md`
- Add `docs/context/CURRENT.md` and `docs/context/CI_PROFILE.md`
- Create one migration task file: `docs/tasks/migrate-stable-ai-template.md`
- Freeze the old live workflow under an archive path before deleting any legacy files
- Replace `Gates` with `AI Gate` in the root workflow set

## Proposed Rollback Point
- migration branch: `chore/migrate-stable-ai-template`
- rollback tag: `before-stable-ai-template-migration`
- optional backup branch: `backup/pre-stable-ai-template-cutover`

## Phase-1 Approval Checklist
- Approve archive-first cutover rather than in-place deletion
- Approve `Gates -> AI Gate` as the live CI switch
- Approve adapting the nested smoke test into a root regression test
- Approve freezing old packet history instead of converting old packets into live tasks
