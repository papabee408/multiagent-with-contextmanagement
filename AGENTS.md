# Task-Driven AI Dev Instructions

## Goal

Keep one live user request mapped to one task file and one PR flow while minimizing manual git and PR work.

## Ownership Matrix

- `AGENTS.md` owns live workflow behavior and routing rules.
- `docs/tasks/<task-id>.md` owns the request-local contract, task state, scope, verification commands, and review summaries.
- `docs/context/CI_PROFILE.md` owns repo CI defaults and check inventory.
- `.context/tasks/<task-id>/*` owns runtime evidence and optional cache output only; it is not required for correctness.
- `docs/context/RESUME_GUIDE.md` owns resume procedure and helper interpretation.
- `docs/tasks/README.md` owns task-directory guidance.
- `README.md` owns onboarding, export, and bootstrap overview.

## Validator Ownership

- `bash scripts/check-task.sh <task-id>` owns task-contract validation.
- `bash scripts/check-scope.sh <task-id>` owns scope validation against target files.
- `scripts/ci/run-ai-gate.sh` reuses those validators in CI and only adds CI-only task resolution plus project-check orchestration.

## Read Order

1. explicit task id, or the current task branch when it maps cleanly to a live task
2. `docs/tasks/<task-id>.md`
3. `bash scripts/status-task.sh [task-id]` when you want a local status summary
4. `docs/context/RESUME_GUIDE.md`
5. `docs/context/PROJECT.md`
6. `docs/context/ARCHITECTURE.md`
7. `docs/context/CONVENTIONS.md`
8. `docs/context/CI_PROFILE.md` only when the task touches git, PR, merge, verification policy, or CI
9. `docs/context/DECISIONS.md` only when the task or diff depends on prior decisions

## Fresh Repo Bootstrap Rule

- If this repository was freshly copied from an exported template bundle and still carries template-source identity or copied template task history, read `docs/context/FRESH_REPO_BOOTSTRAP.md` before feature planning or implementation.
- Use that file only for first-run bootstrap handling. After the repo has been customized, do not treat it as part of the normal session read path.

## Architecture-First Rule

- Before implementation, map the change to existing boundaries in `docs/context/ARCHITECTURE.md`.
- If a boundary does not exist, define a narrow new module boundary in the task plan before editing code.
- Do not keep adding logic to files that already mix multiple concerns; extract responsibilities first.
- Keep presentation/entry logic, domain logic, and IO/integration logic separated.
- Prefer composable modules over all-in-one files so each file has one primary reason to change.

## Intake Rule

- Default policy: one user-visible change cluster per task.
- If a request contains multiple independent clusters, recommend splitting before implementation.
- Recommend splitting when changes touch different screens, domains, risks, verification paths, rollout paths, or likely follow-up paths.
- If the user explicitly insists on bundling, record that in the task intake fields, raise review depth, and avoid `trivial` risk.

## Follow-up Request Rule

- If the current task is `planning`, `awaiting_approval`, `approved`, or `in_progress`, decide whether the follow-up is still the same change cluster before writing code.
- If the task is already `review` and the feedback only addresses review findings without changing the approved goal or PR flow, keep the same task and rerun verification and review inside that task.
- Update the current task first if the follow-up or review feedback keeps the same goal and PR flow, and only after revising goal, target files, verification commands, and risk when needed.
- Open a new task if the follow-up changes the goal, verification path, risk profile, rollout path, or likely review path in a material way.
- Never append a materially new follow-up request to a task already in `review` or `done`; open a new task instead.
- If a new task replaces the current one, bootstrap it with `bash scripts/bootstrap-task.sh <new-task-id> --supersedes <old-task-id> --reason "<why>"` so the old task is explicitly recorded as `superseded`.
- When uncertain, default to a new task. Extra task setup is cheaper than reworking the wrong PR later.

## Improvement Trigger Rule

- If a workflow or template improvement trigger appears while doing the current task, finish the approved task first unless the user explicitly redirects immediately.
- Report the trigger briefly in the final task update using only the trigger, the impact, and the suggested next step.
- Do not start improvement work from the trigger alone.
- Wait for the user to decide whether to discuss it, defer it, or open a dedicated improvement task.

## User-Facing Split Copy

Use short guidance like:

- "이 요청은 기능이 여러 개 섞여 있어서 한 번에 묶는 것보다 나눠서 처리하는 편이 더 빠릅니다."
- "이유는 검증, PR 리뷰, merge, 후속 수정까지 전체 리드타임이 줄기 때문입니다."
- "원하면 제가 작업 단위를 1. 2. 3.으로 나눠서 첫 번째부터 바로 진행하겠습니다."

## Core Task Rule

- One live request = one `docs/tasks/<task-id>.md` file = one PR flow.
- Do not create separate PR tasks, merge tasks, or cleanup tasks for the same request.
- The task file is the only request-scoped contract.
- The task defines both file scope and intent scope.

## Planning And Approval Rule

- When a user gives a new requirement, draft or update the task plan first.
- Show the plan to the user through the task approval flow and wait for explicit approval.
- Start implementation only after approval and `start-task`.

## State Machine

- `planning -> awaiting_approval -> approved -> in_progress -> review -> done`
- `planning|awaiting_approval|approved|in_progress|review -> superseded` when a replacement task takes over the request
- Use scripts for all state transitions.
- Do not hand-edit state fields directly.
- Do not edit implementation files before approval and `start-task`.

## Branch Strategy

- Default strategy: `publish-late`
- Start each new task from a clean worktree.
- `publish-late` allows uncommitted work on the base branch after bootstrap.
- `publish-late` forbids local commits on the base branch.
- Before the first commit in `publish-late`, explicitly create or switch to the task branch.
- `open-task-pr` is the manual publish path only. It does not create branches, stage files, or create commits.

## Local Task Selection Rule

- Local commands select the task in this order: explicit task id, then current task branch.
- If neither is available, pass the task id explicitly.
- Do not rely on `.context/active_task`; older copies of that file are ignored.

## Scope Rule

Only edit target files plus workflow internal files:

- `docs/tasks/<task-id>.md`
- `.context/tasks/<task-id>/*`
- `docs/context/DECISIONS.md` only when the task truly records a reusable decision

## Verification And Review Rule

- Runtime evidence lives only under `.context/tasks/<task-id>/*`.
- Runtime evidence is not tracked in git.
- The task file stores human-readable verification/review summaries plus tracked freshness fingerprints.
- Quality review notes must explicitly confirm architecture boundary placement for changed code.
- `complete-task` requires fresh PASS verification, scope review, and quality review state.
- If the task contract or scoped diff changes, old tracked fingerprints and runtime evidence are stale.

## PR And Merge Rule

- Default landing path: `bash scripts/land-task.sh <task-id>`
- `open-task-pr` is for manual, step-by-step publish control.
- PR body must include explicit `Task-ID` metadata.
- CI resolves the task in this order: explicit `CI_TASK_ID`, PR body `Task-ID`, branch-derived task id, exactly one changed live task file, then fail closed.

## Git Finish Shortcut Rule

- If the user says `git 마무리해`, `git finish this`, or `land current task`, treat that as authorization to run `bash scripts/land-task.sh` for the explicit task id or the current task branch.
- Use that shortcut only when the task is already publish-ready, or after you finish verification, review, and `complete-task` in the same turn.
- Keep the shortcut scoped to commit, PR publish, required-check waiting, merge, local sync, and branch cleanup.

## Session Reset Rule

- Do not scan the whole repo on a new session.
- Read `explicit task id or current task branch -> task file -> bash scripts/status-task.sh [task-id] -> RESUME_GUIDE -> PROJECT -> ARCHITECTURE -> CONVENTIONS`.
- Prefer `bash scripts/status-task.sh [task-id]` when you want a local status summary.
- Treat the task file as the canonical tracked task-local record.
