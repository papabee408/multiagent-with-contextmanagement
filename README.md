# Stable Task-Driven AI Dev Template

This template is for long-running AI-assisted product development where sessions reset often, scope discipline matters, and git/PR operations should stay fast without blurring task boundaries.

## What It Optimizes For

- Fast resume after a brand new AI session
- One live request mapped to one task file and one PR flow
- Explicit approval before implementation starts
- Narrow file scope and narrow request intent
- Architecture-safe incremental changes through explicit boundary checks
- Tracked freshness plus runtime-only evidence for verification and review gating
- One default landing path instead of split publish/merge choreography

## Ownership At A Glance

- `AGENTS.md`: canonical workflow behavior and live process rules
- `docs/tasks/<task-id>.md`: canonical request-scoped contract, task state, scope, and verification/review summaries
- `docs/context/CI_PROFILE.md`: repo-specific CI defaults and check inventory
- `.context/tasks/<task-id>/*`: runtime evidence and optional local cache, not tracked truth and not required for correctness
- `docs/context/RESUME_GUIDE.md`: resume procedure and helper interpretation
- `docs/tasks/README.md`: task-directory guidance and template usage
- `README.md`: onboarding, export, and bootstrap overview

For live workflow rules, follow `AGENTS.md` instead of treating this file as the process authority.

## Standalone Bundle

The repository root is the source tree for the template.

If you want a copyable standalone bundle for a brand new repository, export it with:

```bash
bash scripts/export-stable-template.sh
```

By default, the bundle is written to `.build/stable-ai-dev-template/`.

## New Repo Bootstrap

If you copied an exported bundle into a brand new repository, run this once before feature planning:

```bash
bash scripts/init-project.sh
```

`init-project.sh` rewrites the repo identity docs, regenerates `docs/context/CI_PROFILE.md`, creates a `project-bootstrap` task, and initializes local git on the chosen base branch when needed. When you do not pass options, it infers the initial project name and repo slug from the repository directory name.

If you are driving the repo through Codex CLI, you do not need to memorize the command. In a fresh copied repo you can simply say:

- "프로젝트 셋팅부터 하자."
- "이 템플릿 막 export한 새 repo야. 셋업부터 해줘."

After bootstrap, keep the first conversation bootstrap-only: git/base branch/context docs/CI profile/project-bootstrap. Do not mix product features into that first task.

## High-Level Flow

Use this file as an overview, not the detailed rulebook:

1. bootstrap a task with `bash scripts/bootstrap-task.sh <task-id>`
2. fill the task contract in `docs/tasks/<task-id>.md`
3. submit and approve the plan
4. start implementation with `bash scripts/start-task.sh <task-id>`
5. run verification and reviews
6. land with `bash scripts/land-task.sh <task-id>`

Detailed branch strategy, scope policy, follow-up routing, and improvement-trigger rules live in `AGENTS.md`.

## Publish Overview

- Default landing path: `bash scripts/land-task.sh <task-id>`
- Manual publish path: create or switch to the task branch, create the commit explicitly, then run `bash scripts/open-task-pr.sh <task-id>`
- Task files may override `base-branch` and `branch-strategy` in `## Git / PR` when a specific task truly needs different Git/PR behavior than `docs/context/CI_PROFILE.md`

## Validator Surfaces

- `bash scripts/check-task.sh <task-id>` validates the tracked task contract and merge-readiness fields.
- `bash scripts/check-scope.sh <task-id>` validates the current scoped diff against `## Target Files`.
- `scripts/ci/run-ai-gate.sh` reuses those validators in CI instead of redefining task rules.

## Operator Surfaces

- Treat `docs/tasks/<task-id>.md` as the canonical tracked record for task-local state and merge-readiness summaries.
- Treat `.context/tasks/<task-id>/*` as runtime evidence and optional cache output.
- Local task selection is `explicit task id` first, then `current task branch` when it maps to a live task.
- Prefer `bash scripts/status-task.sh [task-id]` when you want a local status summary.
- Treat `bash scripts/refresh-current.sh [task-id]` as a compatibility alias for `status-task.sh`, not as a persisted dashboard generator.
- If helper surfaces disagree, trust the task file for tracked state and `AGENTS.md` plus `docs/context/CI_PROFILE.md` for workflow behavior.
