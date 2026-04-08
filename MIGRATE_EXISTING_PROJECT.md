# Existing Project Migration Guide

This guide is for replacing older AI workflow templates with `stable-ai-dev-template` in an existing repository.

It assumes this usage model:

1. copy the `stable-ai-dev-template/` folder into the target repo unchanged
2. open Codex in the target repo
3. tell Codex to read `stable-ai-dev-template/MIGRATE_EXISTING_PROJECT.md`
4. let Codex perform the migration from the bundle, not from memory

Do not manually copy template files into the repo root before discovery.

It is written for safety first:

- old template versions may differ
- some repos may be partially customized
- some repos may still have in-flight feature packets
- CI must not be broken during cutover

Use marker-based detection, not version assumptions.

## Bundle-First Safety Model

Treat `stable-ai-dev-template/` as a source bundle until cutover is approved.

That means:

- the bundle stays nested during discovery
- root files are not overwritten during discovery
- Codex must inventory the repo first
- Codex must produce a migration plan before changing root workflow files
- root `AGENTS.md`, `.github/workflows/*`, and existing context docs are cutover files, not discovery files

## Codex Execution Contract

When Codex uses this guide in a target repo, it should follow this exact sequence.

### Phase 0: discovery only

Allowed writes:

- a migration report inside `stable-ai-dev-template/`
- no root workflow or context changes yet

Required outputs:

- old template markers found
- file collision list
- current CI workflow situation
- proposed `CI_PROFILE.md` contents derived from the repo and old CI
- whether there is unfinished old packet work
- proposed migration path

Codex should stop for approval before root-level cutover edits.

### Phase 1: approved cutover work

Allowed writes:

- root files that are part of the new template rollout
- archive folders for old template state
- one migration task contract for the migration PR itself

Not allowed:

- blind overwrite of existing project docs
- blind deletion of old template files
- reuse of old receipts, caches, or run logs as live state

### Phase 2: post-merge cleanup

Optional cleanup only after the repo is already live on the new template:

- delete archived old files in a follow-up PR
- simplify leftover docs
- remove temporary migration notes

Do not treat local git housekeeping as a tracked cleanup task.
After merge, deleting the remote branch, removing a local worktree, and syncing local `main` should stay local-only and must not create new edits in `docs/context/CURRENT.md` or `docs/tasks/*.md`.

## Migration Rules

1. Migrate on a dedicated branch.
2. Start from a clean worktree.
3. Record a rollback point before changing template files.
4. Do not try to keep the old template and the new template both live after cutover.
5. Do not blindly overwrite repo-specific project docs.
6. Do not mechanically convert old receipts, handoffs, or run logs into live state.
7. Treat active in-flight work as a decision point, not an implementation detail.
8. Keep the copied `stable-ai-dev-template/` folder intact until migration is complete.
9. Treat root `AGENTS.md`, root `.gitignore`, and CI workflow changes as explicit cutover steps.

## What Counts As An Old Template

The old template may appear in different shapes. Detect by markers.

| Variant | Typical markers |
| --- | --- |
| Full multi-agent packet workflow | `scripts/gates/run.sh`, `docs/features/_template/`, `.github/workflows/gates.yml`, `docs/context/HANDOFF.md`, `docs/context/CODEX_RESUME.md` |
| Nested bundle copy | `codex-template-multi-agent-process/` directory exists |
| Partial customized fork | some of `scripts/gates/*`, `docs/features/*`, `docs/agents/*`, `workflow-mode.sh`, `execution-mode.sh` exist, but not all |
| Old runtime leftovers only | `.context/active_feature`, `docs/features/<feature-id>/`, `artifacts/roles/*.json`, `run-log.md` remain even if scripts were already modified |

If a repo matches more than one row, treat it as a customized fork.

## Before You Touch Anything

Run this checklist first in the target repo.

1. Create a migration branch.

```bash
git checkout -b chore/migrate-stable-ai-template
```

2. Create a rollback tag or branch.

```bash
git tag before-stable-ai-template-migration
```

3. Confirm the worktree is clean.

```bash
git status --short
```

4. Record the old template markers that exist.

```bash
ls .github/workflows/gates.yml scripts/gates/run.sh docs/context/HANDOFF.md docs/context/CODEX_RESUME.md 2>/dev/null
```

5. Record whether there is active old runtime state.

```bash
cat .context/active_feature 2>/dev/null || true
find docs/features -maxdepth 2 -name brief.md 2>/dev/null | sort
```

6. Run the current repo CI and keep the result.
   This is your last known-good baseline before cutover.

7. Copy the source bundle into the repo if it is not there yet.

```text
stable-ai-dev-template/
```

8. Ask Codex to produce a migration report before applying root changes.
   Codex should inspect the repo and propose the CI profile. The user should not have to design CI by hand.

Stop the migration if:

- the repo already has failing baseline CI unrelated to migration
- there is a release or hotfix in progress on the same branch line
- there is an in-flight feature packet nobody has reviewed yet
- you cannot identify the project platform and framework

## Decide How To Handle In-Flight Work

This is the most important safety decision.

### Recommended: finish or close old in-flight features first

If the repo has an active feature packet, complete or intentionally close it under the old template before migrating.

This is the safest path because it avoids mixing:

- old feature packets
- old receipts and gate artifacts
- new task contracts

Here, "unfinished" means a packet that is still active, not completed, or not intentionally closed. If the team normally finishes all packets before shutting down work, this case may not apply.

### If you must migrate with unfinished work

Do not try to auto-convert the old packet.

Instead:

1. Freeze the old packet.
2. Copy the business intent into one new task file.
3. Archive the old packet as historical reference only.

The new task should manually capture:

- goal
- non-goals
- approved scope
- target files
- verification commands
- known blockers
- current diff intent

Do not carry forward:

- old `run-log.md`
- old role receipts
- old gate receipts
- old approval hashes
- old baseline caches

## What To Carry Forward

Keep the meaning, not the old structure.

| Old source | New home | Migration rule |
| --- | --- | --- |
| `docs/context/PROJECT.md` | `docs/context/PROJECT.md` | keep product intent, constraints, critical flows; rewrite to the new section format |
| `docs/context/ARCHITECTURE.md` | `docs/context/ARCHITECTURE.md` | keep actual module boundaries and placement rules |
| `docs/context/CONVENTIONS.md` | `docs/context/CONVENTIONS.md` | keep reuse, hardcoding, testing, visual-change rules |
| `docs/context/RULES.md` | usually `docs/context/CONVENTIONS.md` | fold only still-valid coding rules into conventions |
| `docs/context/DECISIONS*.md` | `docs/context/DECISIONS.md` | keep only decisions that still matter |
| repo-specific `test-guide.md` | `test-guide.md` | keep if still useful |
| old test/build commands from gates or scripts | `docs/context/CI_PROFILE.md` | do not keep them buried inside old gate scripts |

## File Handling Rules

Do not treat every bundle file the same.

### Direct-add or direct-replace candidates

These are usually safe to install from the bundle after approval:

- `.github/workflows/ai-gate.yml`
- `docs/tasks/README.md`
- `docs/tasks/_template.md`
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
- `scripts/refresh-current.sh`
- `scripts/review-quality.sh`
- `scripts/review-scope.sh`
- `scripts/run-task-checks.sh`
- `scripts/setup-ci-profile.sh`
- `scripts/start-task.sh`
- `scripts/submit-task-plan.sh`

### Merge-required files

These must be rewritten or merged carefully:

- root `AGENTS.md`
- root `.gitignore`
- `docs/context/PROJECT.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/CONVENTIONS.md`
- `docs/context/DECISIONS.md`
- `docs/context/CI_PROFILE.md`
- `docs/context/CURRENT.md`
- `test-guide.md`

### Reference-only bundle files

Do not blindly install these into root on an existing product repo:

- `stable-ai-dev-template/README.md`
- `stable-ai-dev-template/tests/smoke.sh`

Use them as reference material or rename them if you explicitly want them in the target repo.

## What To Archive Or Remove

These are old live-state structures and should not stay active after cutover.

Archive first if you need history. Remove later when the migration PR is stable.

| Old path or concept | Action |
| --- | --- |
| `.github/workflows/gates.yml` | replace with new `ai-gate.yml` |
| `scripts/gates/` | archive or remove after extracting repo-specific commands |
| `scripts/start-feature.sh`, `scripts/complete-feature.sh`, `scripts/workflow-mode.sh`, `scripts/execution-mode.sh`, `scripts/promote-workflow.sh`, `scripts/sync-handoffs.sh` | archive or remove |
| `docs/features/` live packets | archive; do not keep as active workflow state |
| `docs/agents/` old role files | archive or remove |
| `docs/context/HANDOFF.md`, `docs/context/CODEX_RESUME.md`, `docs/context/GATES.md`, `docs/context/MAINTENANCE*.md`, `docs/context/MULTI_AGENT_PROCESS.md` | archive; they are not part of the new live runtime |
| `.context/active_feature`, `.context/active_session`, old receipt/cache files | archive or delete; do not reuse |

## Old-To-New Concept Mapping

| Old template concept | New template concept |
| --- | --- |
| feature packet | one task contract |
| `docs/features/<feature-id>/brief.md` + `plan.md` + handoffs + `test-matrix.md` + `run-log.md` | `docs/tasks/<task-id>.md` |
| `.context/active_feature` | `.context/active_task` |
| `HANDOFF.md` + `CODEX_RESUME.md` | `CURRENT.md` |
| `Gates` workflow | `AI Gate` workflow |
| `scripts/gates/run.sh` | `scripts/ci/run-ai-gate.sh` |
| role chain | single task lifecycle with explicit approval, verification, scope review, and quality review |

## Recommended Cutover Sequence

Use this order. Do not improvise the sequence on the first repo.

### 1. Keep the bundle nested and create a migration report

Do not start by copying bundle files into root.

Codex should first inspect:

- current old-template markers
- current CI workflows
- current branch protection assumptions
- root file collisions
- current project context docs

Then Codex should write a short migration report inside the bundle and stop for approval.

### 2. Install new runtime files carefully

Apply the new template from the bundle into root using the file-handling rules above.

Important:

- merge `.gitignore` so root ignores `.context/`
- add `docs/tasks/*`
- add `scripts/*` and `scripts/ci/*`
- add `.github/workflows/ai-gate.yml`
- do not overwrite existing context docs with placeholders
- do not overwrite root `README.md` from the bundle
- do not install `tests/smoke.sh` to root unless you intentionally rename or adapt it

### 3. Create one migration task for the migration PR itself

After `docs/tasks/*` and the task scripts exist in root, create one task contract for the migration work:

- `docs/tasks/migrate-stable-ai-template.md`

That task should cover only the migration files and commands.

This matters because the new PR gate needs one concrete task to validate.

### 4. Rewrite project context into the new format

Fill these first:

- `docs/context/PROJECT.md`
- `docs/context/ARCHITECTURE.md`
- `docs/context/CONVENTIONS.md`
- `docs/context/DECISIONS.md`
- `docs/context/CURRENT.md`

Do not copy old operational docs into these files wholesale. Rewrite them into the new sections.

### 5. Generate the CI profile

Run:

```bash
bash scripts/setup-ci-profile.sh
```

This gives you a first pass for:

- platform
- framework
- package manager
- PR fast checks
- high-risk checks
- full project checks

Then review and edit:

- `docs/context/CI_PROFILE.md`

Important:

- Codex should extract real project commands from old gate scripts, existing CI workflows, and repo manifests
- the user should only need to confirm platform/framework when Codex cannot infer them confidently
- do not leave project-specific checks hidden in legacy shell wrappers
- if Codex cannot infer a safe command, it should leave an explicit TODO note in `CI_PROFILE.md` instead of guessing

### 6. Handle unfinished old work

Choose one path:

- no unfinished feature packets: continue
- one unfinished feature packet: create one new task file and archive the old packet
- many unfinished feature packets: stop and resolve them before cutover

If converting one unfinished feature:

1. Create a new task id.
2. Summarize the approved intent into `docs/tasks/<task-id>.md`.
3. Set clear target files and verification commands.
4. Archive the old `docs/features/<feature-id>/` folder.

### 7. Cut over CI safely

The new required workflow should be `AI Gate`, not `Gates`.

There are three safe cases:

1. `Gates` exists and is currently required
   - this is an admin cutover
   - do not assume the migration PR will pass old `Gates`
   - use the migration task so `AI Gate` can validate the PR
   - once `AI Gate` is green on the migration PR, update branch protection from `Gates` to `AI Gate`
   - only then merge the migration PR

2. `Gates` exists but is not required
   - add `AI Gate`
   - validate the migration PR with `AI Gate`
   - after merge, make `AI Gate` required

3. there is no old required CI workflow
   - add `AI Gate`
   - validate the migration PR
   - make `AI Gate` required after the first successful merge if desired

Safe rules:

- do not remove old required CI before you have a green replacement path
- do not leave both `Gates` and `AI Gate` as long-term required checks
- do not switch branch protection after merge unless you are prepared for one PR worth of confusion

Repository-admin step:

- if `Gates` is currently required, changing the required check is part of the cutover, not a follow-up afterthought
- Codex should inspect the current required-check situation and tell the operator the exact next step
- if repo admin tooling is available, Codex may perform the branch-protection change with approval
- if admin tooling is not available, Codex should provide the exact GitHub UI path or CLI command instead of vague instructions

### 8. Switch the root instructions

Update root `AGENTS.md` only in the cutover phase, not discovery.

Root `AGENTS.md` is the behavioral switch that makes new Codex sessions follow the new workflow.

### 9. Archive old template files

Prefer a controlled archive step over blind deletion on the first pass.

Examples of safe archive locations:

- `migration-archive/old-template/`
- `docs/archive/old-ai-template/`

If the repo is large and you want a smaller final diff, archive in one commit and delete in a later cleanup PR.

### 10. Validate locally before opening the PR

Run at minimum:

```bash
bash scripts/check-context.sh
```

Also run the project-specific commands from:

- `docs/context/CI_PROFILE.md`

If you chose to install a renamed copy of the bundle smoke test, run that too.

If the repo already has trusted build/test commands, run those too before relying on the new PR gate.

## Batch Rollout Strategy Across Many Repos

Do not roll this to every repo at once.

Use this order:

1. One canary repo per platform family:
   - web
   - backend
   - mobile
   - game
2. Adjust the CI profile defaults and migration notes from the canary results.
3. Roll out one PR per repo.
4. Keep a migration checklist comment in each PR.
5. Only then switch required checks repo by repo.

This matters because old versions may differ, but the bigger risk is repo-specific CI assumptions.

## Rollback Plan

If the migration PR is unstable:

1. do not merge it
2. keep the old required check in place
3. reset the branch to the rollback tag or branch
4. refine the CI profile and context mapping
5. retry on a fresh migration branch

Do not partially merge:

- new `AGENTS.md`
- new `AI Gate`
- old required `Gates`
- old live feature packets

in the same long-lived state.

## Migration Done Criteria

The migration is complete only when all of these are true:

- old template is no longer the live workflow
- `AI Gate` passes on the migration PR
- branch protection points to `AI Gate`, not `Gates`
- root `.gitignore` ignores `.context/`
- project context docs are real, not placeholders
- `CI_PROFILE.md` is filled with repo-specific commands that Codex derived and the operator approved
- there is no active dependence on old feature packets, handoffs, or receipts
- the next fresh AI session can resume from `CURRENT.md` and the active task without reading old operational docs

## Practical Recommendation

On the first pass for each repo:

- favor archive over delete
- favor manual task reconstruction over packet auto-conversion
- favor one-repo-at-a-time PRs over bulk replacement
- favor explicit CI profile review over automatic guesses

This migration is successful when the new template becomes simpler and more trustworthy than the old one, not when the diff is minimal.
