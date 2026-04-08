# Feature Plan

## Scope
- target files:
  - `stable-ai-dev-template/README.md`
  - `stable-ai-dev-template/AGENTS.md`
  - `stable-ai-dev-template/.gitignore`
  - `stable-ai-dev-template/docs/context/PROJECT.md`
  - `stable-ai-dev-template/docs/context/ARCHITECTURE.md`
  - `stable-ai-dev-template/docs/context/CONVENTIONS.md`
  - `stable-ai-dev-template/docs/context/CURRENT.md`
  - `stable-ai-dev-template/docs/context/DECISIONS.md`
  - `stable-ai-dev-template/docs/tasks/README.md`
  - `stable-ai-dev-template/docs/tasks/_template.md`
  - `stable-ai-dev-template/scripts/_lib.sh`
  - `stable-ai-dev-template/scripts/bootstrap-task.sh`
  - `stable-ai-dev-template/scripts/check-context.sh`
  - `stable-ai-dev-template/scripts/check-task.sh`
  - `stable-ai-dev-template/scripts/check-scope.sh`
  - `stable-ai-dev-template/scripts/run-task-checks.sh`
  - `stable-ai-dev-template/scripts/refresh-current.sh`
  - `stable-ai-dev-template/scripts/complete-task.sh`
  - `stable-ai-dev-template/scripts/log-decision.sh`
  - `stable-ai-dev-template/test-guide.md`
  - `stable-ai-dev-template/tests/smoke.sh`
- out-of-scope files:
  - existing `scripts/**`, `docs/context/**`, and `docs/features/**` outside this feature packet
  - current `codex-template-multi-agent-process/` export contents
  - unrelated product or UI code anywhere outside `stable-ai-dev-template/`

## RQ -> Task Mapping
- `RQ-001` -> Task 1
- `RQ-002` -> Task 2
- `RQ-003` -> Task 2
- `RQ-004` -> Task 3

## Architecture Notes
- target layer / owning module: `stable-ai-dev-template/` is a standalone copyable root with `docs/context`, `docs/tasks`, and `scripts` as the only required control surfaces
- dependency constraints / forbidden imports: template scripts must depend only on Bash, Git, and hash utilities; do not reintroduce generated handoffs, role receipts, approval caches, or repo-specific workflow state
- shared logic or component placement: all common parsing, hashing, active-task resolution, and baseline logic lives in `stable-ai-dev-template/scripts/_lib.sh`

## Reuse and Config Plan
- existing abstractions to reuse: reuse only the idea of shell-based validation and git diff inspection; keep implementation self-contained inside the new template
- extraction candidates for shared component/helper/module: centralize task parsing, baseline comparison, and verification fingerprinting in `_lib.sh` instead of duplicating logic across scripts
- constants/config/env to centralize: runtime paths such as `.context/active_task`, `.context/tasks/<task-id>/baseline.tsv`, verification receipt names, and workflow-internal allowed files must be defined in one helper layer
- hardcoded values explicitly allowed: template section names, status enums, and bootstrap file names that form the public contract of the template

## Execution Strategy
- implementer mode: `serial`
- merge owner: `implementer`
- shared files reserved for parent:
  - none
- if `parallel`, each task card below must own a disjoint backtick-wrapped file set

## Task Cards
### Task 1
- files:
  - `stable-ai-dev-template/README.md`
  - `stable-ai-dev-template/AGENTS.md`
  - `stable-ai-dev-template/.gitignore`
  - `stable-ai-dev-template/docs/context/PROJECT.md`
  - `stable-ai-dev-template/docs/context/ARCHITECTURE.md`
  - `stable-ai-dev-template/docs/context/CONVENTIONS.md`
  - `stable-ai-dev-template/docs/context/CURRENT.md`
  - `stable-ai-dev-template/docs/context/DECISIONS.md`
  - `stable-ai-dev-template/docs/tasks/README.md`
  - `stable-ai-dev-template/docs/tasks/_template.md`
  - `stable-ai-dev-template/test-guide.md`
- change:
  - Define the new template's source-of-truth order, task contract, context docs, and explicit rule against unrelated design changes.
- done when:
  - A new session can follow `CURRENT.md -> active task -> task contract -> durable context docs` and understand the intended workflow without the old multi-agent engine.

### Task 2
- files:
  - `stable-ai-dev-template/scripts/_lib.sh`
  - `stable-ai-dev-template/scripts/bootstrap-task.sh`
  - `stable-ai-dev-template/scripts/check-context.sh`
  - `stable-ai-dev-template/scripts/check-task.sh`
  - `stable-ai-dev-template/scripts/check-scope.sh`
  - `stable-ai-dev-template/scripts/run-task-checks.sh`
  - `stable-ai-dev-template/scripts/refresh-current.sh`
  - `stable-ai-dev-template/scripts/complete-task.sh`
  - `stable-ai-dev-template/scripts/log-decision.sh`
- change:
  - Implement the smaller fail-closed workflow around one task file, content-hash baseline handling, fresh verification receipts, and completion-time revalidation.
- done when:
  - The new template can bootstrap a task, refresh resume state, reject out-of-scope edits, reject stale verification, and complete a task without any generated handoff or role receipt layer.

### Task 3
- files:
  - `stable-ai-dev-template/tests/smoke.sh`
  - `stable-ai-dev-template/README.md`
- change:
  - Add a copyable smoke test and usage guidance that prove the new template's dirty-baseline and verification-freshness behavior.
- done when:
  - Running the smoke test demonstrates the intended safety properties and the README tells users exactly when to use each script.
