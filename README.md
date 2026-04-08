# Stable Task-Driven AI Dev Template

This repository now treats the root as the live stable template.

## What Is Live

- root `AGENTS.md`
- root `docs/tasks/*`
- root `docs/context/*`
- root `scripts/*`
- root `.github/workflows/ai-gate.yml`

## What Is Historical

- `migration-archive/old-ai-template/`
  - archived multi-agent packet workflow
  - reference only
  - not part of the live runtime

## What Is Still Nested On Purpose

- `stable-ai-dev-template/`
  - the source bundle used for this migration
  - kept temporarily during stabilization
  - can be removed in a later cleanup PR after the root workflow is trusted

## Default Flow

1. Bootstrap a task

```bash
bash scripts/bootstrap-task.sh <task-id>
```

2. Fill and submit the task contract

```bash
bash scripts/submit-task-plan.sh <task-id>
```

3. After approval, start work

```bash
bash scripts/approve-task.sh <task-id> --by "<approver>" --note "<approval note>"
bash scripts/start-task.sh <task-id>
```

4. Verify and review

```bash
bash scripts/run-task-checks.sh <task-id>
bash scripts/review-scope.sh <task-id> --summary "<scope note>"
bash scripts/review-quality.sh <task-id> --summary "<quality note>" --reuse pass --hardcoding pass --tests pass --request-scope pass
bash scripts/complete-task.sh <task-id> "<summary>" "<next-step>"
```

5. Publish and merge

```bash
git switch -c task/<task-id>
git add <approved-files>
git commit -m "task(<task-id>): <summary>"
bash scripts/open-task-pr.sh <task-id>
bash scripts/merge-task-pr.sh <task-id>
```

## Read Order

1. `docs/context/CURRENT.md`
2. `.context/active_task`
3. `docs/tasks/<task-id>.md`
4. `docs/context/PROJECT.md`
5. `docs/context/ARCHITECTURE.md`
6. `docs/context/CONVENTIONS.md`
7. `docs/context/CI_PROFILE.md` when git, PR, CI, or merge policy matters
8. `docs/context/DECISIONS.md` when a past decision matters

## User-Facing Split Copy

- "이 요청은 기능이 여러 개 섞여 있어서 한 번에 묶는 것보다 나눠서 처리하는 편이 더 빠릅니다."
- "이유는 검증, PR 리뷰, merge, 후속 수정까지 전체 리드타임이 줄기 때문입니다."
- "원하면 제가 작업 단위를 1. 2. 3.으로 나눠서 첫 번째부터 바로 진행하겠습니다."

## Migration Notes

- discovery report: `stable-ai-dev-template/MIGRATION_REPORT.md`
- legacy workflow archive: `migration-archive/old-ai-template/`
- migration stabilization should prove root `tests/smoke.sh` and root `AI Gate`
