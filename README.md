# Stable Task-Driven AI Dev Template

This template is for long-running AI-assisted product development where sessions reset often, scope discipline matters, and git/PR operations should stay fast without blurring task boundaries.

## What It Optimizes For

- Fast resume after a brand new AI session
- One live request mapped to one task file and one PR flow
- Explicit approval before implementation starts
- Narrow file scope and narrow request intent
- Architecture-safe incremental changes through explicit boundary checks
- Runtime-only receipts with fresh verification and review gating
- Minimal operator git work through explicit publish and explicit manual merge

## Core Model

- one live request = one `docs/tasks/<task-id>.md`
- one task = one PR flow
- one active task pointer = `.context/active_task`
- one runtime resume surface = `.context/current.md`
- one tracked context guide = `docs/context/CURRENT.md`

## Read Order

1. `.context/current.md` if present
2. `.context/active_task` if present
3. `docs/tasks/<task-id>.md`
4. `docs/context/CURRENT.md`
5. `docs/context/PROJECT.md`
6. `docs/context/ARCHITECTURE.md`
7. `docs/context/CONVENTIONS.md`
8. `docs/context/CI_PROFILE.md` only when needed
9. `docs/context/DECISIONS.md` only when needed

## Branch Strategy

Default strategy: `publish-late`

- uncommitted task work on the base branch is allowed
- local commits on the base branch are not allowed
- before the first commit, explicitly create or switch to the task branch
- `open-task-pr` is publish-only; it does not create branches, stage files, or create commits

Use `early-branch` when the task is long-running, checkpoint-heavy, mixed, or likely to need parallel work.

## Runtime State

- runtime receipts and task-local state live only under `.context/tasks/<task-id>/*`
- `.context/` is ignored by git
- `.context/current.md` keeps the mutable human-readable runtime snapshot
- `docs/context/CURRENT.md` stays tracked as stable resume guidance
- the task file keeps the tracked request contract, verification, and review summaries

## New Repo Bootstrap

If you copied `stable-ai-dev-template/` into a brand new repository, run this once before feature planning:

```bash
bash scripts/init-project.sh
```

`init-project.sh` rewrites the repo identity docs, regenerates `docs/context/CI_PROFILE.md`, removes copied template task history, creates a `project-bootstrap` task, and initializes local git on the chosen base branch when needed. When you do not pass options, it infers the initial project name and repo slug from the repository directory name.

If you are driving the repo through Codex CLI, you do not need to memorize the command. In a fresh copied repo you can simply say:

- "프로젝트 셋팅부터 하자."
- "이 템플릿 막 복사한 새 repo야. 셋업부터 해줘."

The intended agent behavior is to run the bootstrap flow first and then continue inside `project-bootstrap`.

After that, keep the first conversation bootstrap-only: git/base branch/context docs/CI profile/project-bootstrap. Do not mix product features into that first task.

## Workflow

Default interpretation: when a new requirement arrives, write the task plan first, get explicit user approval, and only then implement.

1. Bootstrap the task

```bash
bash scripts/bootstrap-task.sh <task-id>
```

2. Fill the task contract
3. Submit and approve the plan

```bash
bash scripts/submit-task-plan.sh <task-id>
bash scripts/approve-task.sh <task-id> --by "<approver>" --note "<approval note>"
bash scripts/start-task.sh <task-id>
```

4. Implement only inside `## Target Files`
5. Verify and review

```bash
bash scripts/run-task-checks.sh <task-id>
bash scripts/review-scope.sh <task-id> --summary "<scope note>"
bash scripts/review-quality.sh <task-id> --summary "<quality note>" --architecture pass ...
bash scripts/complete-task.sh <task-id> "<summary>" "<next-step>"
```

6. Publish

```bash
git switch -c task/<task-id>
git add <approved-files>
git commit -m "task(<task-id>): <summary>"
bash scripts/open-task-pr.sh <task-id>
```

7. Merge manually

```bash
gh pr merge <pr-number> --squash --delete-branch
git switch main
git fetch origin main
git merge --ff-only origin/main
git branch -d task/<task-id> 2>/dev/null || true
rm -f .context/active_task
bash scripts/refresh-current.sh
```

## Git Finish Shortcut

When the current task is already `done`, you can land it end to end with:

```bash
bash scripts/land-task.sh <task-id>
```

`land-task.sh` stages approved task-owned changes, creates the task commit on the task branch, opens or updates the PR, waits for required checks, squash merges, syncs local `main`, prunes deleted remote refs, deletes the local task branch, clears `.context/active_task`, and refreshes `.context/current.md`.

In Codex CLI, a short request like "git 마무리해" should trigger that flow for the active task.

## Intake Policy

Default policy: one user-visible change cluster per task.

If a request mixes multiple independent features, recommend splitting first. Use short guidance like:

- "이 요청은 기능이 여러 개 섞여 있어서 한 번에 묶는 것보다 나눠서 처리하는 편이 더 빠릅니다."
- "이유는 검증, PR 리뷰, merge, 후속 수정까지 전체 리드타임이 줄기 때문입니다."
- "원하면 제가 작업 단위를 1. 2. 3.으로 나눠서 첫 번째부터 바로 진행하겠습니다."

## Follow-up Routing

When a small extra request appears during a task, make the routing decision before coding:

- If the task is still `planning`, `awaiting_approval`, `approved`, or `in_progress`, update that task only when the follow-up keeps the same goal and PR flow.
- Before absorbing the follow-up, revisit `Goal`, `Target Files`, `Verification Commands`, and `risk-level`.
- If the task is already `review` or `done`, or the follow-up materially changes verification, risk, or review path, bootstrap a new task.
- When unsure, open a new task. That is usually faster than fixing the wrong task and PR later.

## Improvement Trigger Reporting

If a workflow or template improvement trigger shows up during delivery:

- finish the current approved task first
- report the trigger briefly in the final update with `trigger`, `impact`, and `proposal`
- wait for the user to choose discussion, defer, or a dedicated improvement task
- do not start the improvement work until the user explicitly chooses to proceed
