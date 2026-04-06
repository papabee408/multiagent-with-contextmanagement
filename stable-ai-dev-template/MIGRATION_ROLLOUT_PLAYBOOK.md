# Migration Rollout Playbook

This playbook is for migrating multiple existing repositories to `stable-ai-dev-template` safely.

Use this together with:

- `MIGRATE_EXISTING_PROJECT.md`

Use this playbook when:

- you are migrating more than one repo
- old template variants differ across repos
- CI / branch protection / old packet state may differ repo by repo
- you want repeatable stop points instead of one-shot cutover

## Core Recommendation

Do not run migration as one blind copy-and-cutover step.

Do not require a human to supervise every tiny command either.

Use this model:

1. one standard migration guide in the repo
2. one standard rollout playbook across repos
3. hard stop points between phases
4. require a report and approval at each stop point

Short version:

- one document
- multiple phases
- stop after each phase
- review before the next phase

## What To Standardize

These should be identical across repos:

- migration phase names
- stop points
- report format
- approval criteria
- rollback policy
- stabilization policy

These may differ per repo:

- old template markers
- current CI commands
- branch protection state
- active old packet state
- project-specific `CI_PROFILE.md`

## Fleet Rollout Order

Do not migrate every repo at once.

Recommended order:

1. template repo itself
2. one canary repo per platform family
   - web
   - backend
   - mobile
   - game
3. one small/low-risk real repo
4. the rest in small batches

Good batch size:

- 1 repo first
- then 2-3 repos
- then the rest

Do not batch repos that share the same release window or same critical branch line.

## Per-Repo Phase Model

Every repo should go through the same six phases.

### Phase 0: Discovery Only

Purpose:

- inspect the repo
- identify old template shape
- identify collisions and risks
- produce a migration report

Allowed:

- adding `stable-ai-dev-template/`
- writing `stable-ai-dev-template/MIGRATION_REPORT.md`

Not allowed:

- editing root workflow files
- editing root context docs
- deleting old template files
- touching branch protection

Required report content:

- old template markers found
- file collisions
- current CI/workflow state
- branch protection state
- unfinished old packet status
- proposed `CI_PROFILE.md`
- proposed cutover method
- proposed rollback point

Stop point:

- stop here and review the report

### Phase 1: Preflight Decision

Purpose:

- decide whether this repo is ready to migrate now

Required decisions:

- proceed now / delay
- old active packet close vs freeze
- `Gates -> AI Gate` transition method
- migration branch name
- rollback tag/branch name

Stop point:

- approve or reject cutover

Reject cutover if:

- baseline CI is already broken for unrelated reasons
- there is active release/hotfix pressure
- old packet state is unclear
- branch protection transition is unclear
- platform/framework cannot be identified confidently

### Phase 2: Cutover Branch

Purpose:

- make the root-level template changes on a dedicated branch

Allowed:

- root template rollout files
- migration task creation
- archive/freeze markers for old live state

Not allowed:

- blind overwrite of project docs
- blind deletion of old template history
- unrelated product changes

Required outputs:

- migration branch
- rollback point created
- new root files installed
- migration task created
- PR opened

Stop point:

- stop when PR exists and `AI Gate` is green

### Phase 3: Merge Readiness

Purpose:

- confirm that the migration PR is actually safe to merge

Required checks:

- `AI Gate` green
- required check transition plan is ready
- no unrelated product code changes
- old active packet handled explicitly
- root live path points to the new workflow

Stop point:

- approve merge

### Phase 4: Stabilization

Purpose:

- prove the repo really works on the new workflow after cutover

This phase matters because a structural cutover can still leave old workflow behavior alive.

Required checks:

- old `Gates` is no longer the live required gate
- old PR-triggered workflow is disabled or clearly non-live
- `AI Gate` runs successfully by itself
- `CURRENT.md`, task flow, and `CI_PROFILE.md` behave correctly
- one small canary task completes end to end on the new workflow

Stop point:

- only call migration done after stabilization passes

### Phase 5: Cleanup

Purpose:

- remove leftovers after the repo has already proven stable

Allowed:

- archive pruning
- bundle removal
- document cleanup
- optional branch protection tightening

Not required for migration success:

- full archive deletion
- aggressive history cleanup

Recommendation:

- keep this as a separate follow-up PR

Important distinction:

- tracked repo cleanup belongs here
- local branch deletion, worktree removal, and local `main` sync do not

Post-merge git housekeeping is local-only operational cleanup.
Do not create a tracked cleanup task or edit `docs/context/CURRENT.md` / `docs/tasks/*.md` just to record those local actions.

## Required Reports At Each Stop Point

Codex should not just say "done".

Use these minimum reports.

### After Phase 0

Must report:

- old template type
- active old packet yes/no
- CI/workflow status
- required check status
- collision list
- migrate now yes/no

### After Phase 2

Must report:

- files changed
- old packet handling
- PR URL
- `AI Gate` status
- merge blocker if any

### After Phase 4

Must report:

- whether old `Gates` still runs anywhere
- whether `AI Gate` is the only live required gate
- whether a canary task passed
- migration truly done yes/no
- remaining known limitation if any

## Human Approval Policy

Require approval at these points:

1. after Phase 0 report
2. before merge in Phase 3
3. after stabilization if cleanup is destructive

Do not require approval between every tiny command.

That is too slow and adds noise without improving safety.

## Recommended Operator Prompts

These prompts are meant to be pasted into Codex inside the target repo.

### Prompt A: Phase 0 Discovery

```text
Read `stable-ai-dev-template/MIGRATE_EXISTING_PROJECT.md` and `stable-ai-dev-template/MIGRATION_ROLLOUT_PLAYBOOK.md`.

Perform Phase 0 discovery only.

- Do not edit root files
- Do not cut over anything yet
- Only inspect the repo and write a migration report inside `stable-ai-dev-template/`

The report must include:
- old template markers
- file collisions
- CI/workflow state
- branch protection state
- unfinished old packet status
- proposed `CI_PROFILE.md`
- proposed cutover path
- proposed rollback point

Stop after the report and wait for approval.
```

### Prompt B: Approved Cutover

```text
Proceed with Phase 2 cutover using `stable-ai-dev-template/MIGRATE_EXISTING_PROJECT.md` and `stable-ai-dev-template/MIGRATION_ROLLOUT_PLAYBOOK.md`.

Rules:
- use a dedicated migration branch
- record a rollback point first
- no blind overwrite
- no unrelated product changes
- handle old active packet explicitly by close or freeze
- create one migration task for the migration PR
- stop when the migration PR exists and `AI Gate` is green

Then report:
- changed files
- old packet handling
- PR URL
- `AI Gate` status
- any remaining merge blocker
```

### Prompt C: Stabilization

```text
Perform Phase 4 stabilization only.

Check:
- whether old `Gates` still runs on PR events
- whether `AI Gate` is the only live required gate
- whether task flow, CURRENT snapshot, and CI profile behave correctly
- whether one small canary task can complete end to end on the new workflow

Do not do archive cleanup yet.

At the end, answer:
- migration truly done: yes/no
- if no, what exact blocker remains
- if yes, what cleanup is still optional
```

## Rollback Policy

Every repo migration must have a rollback point before root changes.

Minimum rollback artifacts:

- migration branch
- rollback tag or backup branch
- last known-good old CI status

Rollback if:

- migration PR cannot get `AI Gate` green without unrelated code churn
- branch protection transition cannot be completed safely
- stabilization shows old/new live workflow collision
- canary task fails due to template/runtime mismatch

## What Counts As Successful Migration

A repo is only considered migrated when all of these are true:

1. root workflow is on the new template
2. `AI Gate` is the live required check
3. old live PR gate is disabled or non-live
4. task-based workflow is actually in use
5. one canary task passes end to end on the new system

If one of these is missing, the repo is not done yet.

## Known Limitation To Keep In Mind

Today, the template can strongly enforce workflow consistency, but it still cannot cryptographically prove that a final independent review actually came from an external reviewer using only repo-authored files.

That means:

- use branch protection
- prefer GitHub review requirements for sensitive repos
- treat "independent final review" primarily as a process control, not a perfect provenance proof

## Recommended Default For Most Teams

If you want the safest practical path without too much overhead:

- migrate one repo at a time
- stop after Phase 0
- stop again before merge
- always run stabilization
- do cleanup later

That is the best speed/safety tradeoff for real migrations.
