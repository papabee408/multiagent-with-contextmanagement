# Task-Driven AI Dev Instructions

## Goal

Keep one live user request mapped to one task file and one PR flow while minimizing manual git and PR work.

## Read Order

1. `docs/context/CURRENT.md`
2. `.context/active_task`
3. `docs/tasks/<task-id>.md`
4. `docs/context/PROJECT.md`
5. `docs/context/ARCHITECTURE.md`
6. `docs/context/CONVENTIONS.md`
7. `docs/context/CI_PROFILE.md` only when the task touches git, PR, merge, verification policy, or CI
8. `docs/context/DECISIONS.md` only when the task or diff depends on prior decisions

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

## State Machine

- `planning -> awaiting_approval -> approved -> in_progress -> review -> done`
- Use scripts for all state transitions.
- Do not hand-edit state fields directly.
- Do not edit implementation files before approval and `start-task`.

## Branch Strategy

- Default strategy: `publish-late`
- `publish-late` allows uncommitted work on the base branch.
- `publish-late` forbids local commits on the base branch.
- Before the first commit in `publish-late`, explicitly create or switch to the task branch.
- Normal `publish-late` flow:
  1. work on the base branch with uncommitted task-owned changes
  2. create or switch to the task branch
  3. stage approved files explicitly
  4. create the commit explicitly
  5. run `open-task-pr`
- Use `early-branch` for long-running, mixed, checkpoint-heavy, or parallelizable work.
- `open-task-pr` is publish-only. It does not create branches, stage files, or create commits.

## Scope Rule

Only edit target files plus workflow internal files:

- `docs/tasks/<task-id>.md`
- `docs/context/CURRENT.md`
- `.context/active_task`
- `.context/tasks/<task-id>/*`
- `docs/context/DECISIONS.md` only when the task truly records a reusable decision

## Verification And Review Rule

- Runtime receipts live only under `.context/tasks/<task-id>/*`.
- Runtime receipts are not tracked in git.
- The task file stores human-readable verification and review summary fields.
- Quality review notes must explicitly confirm architecture boundary placement for changed code.
- `complete-task` requires fresh PASS runtime receipts for verification, scope review, and quality review.
- If the task contract or scoped diff changes, old runtime receipts are stale.

## PR And Merge Rule

- `open-task-pr` publishes an already committed task branch.
- `merge-task-pr` is the default merge path.
- PR body must include explicit `Task-ID` metadata.
- CI resolves the task by PR body `Task-ID` first and by changed task file only as fallback.
- `merge-task-pr` must verify:
  - the PR is open
  - the base branch matches the task
  - the PR body `Task-ID` matches the task
  - the latest PR head SHA has all required checks green
- After merge, sync local base branch and clean local and remote task branches.

## Session Reset Rule

- Do not scan the whole repo on a new session.
- Read `CURRENT -> active_task -> task file -> PROJECT -> ARCHITECTURE -> CONVENTIONS`.
- Use `CURRENT.md` as the default resume surface.
