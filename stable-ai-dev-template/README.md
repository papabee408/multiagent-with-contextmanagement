# Stable AI Dev Template

This template is for long-running AI-assisted product development where sessions reset often, scope discipline matters, and stability is more important than workflow theatrics.

For replacing older template variants in an existing repository, see `MIGRATE_EXISTING_PROJECT.md`.
For rolling this out across multiple repos safely, see `MIGRATION_ROLLOUT_PLAYBOOK.md`.

## What It Optimizes For

- Fast resume after a brand new AI session
- Consistent implementation quality across multiple tasks
- Explicit user approval before implementation starts
- Strict control over which files a task may touch
- Fresh verification before a task is marked complete
- Separate scope review and quality review before completion
- Small, inspectable state that is easy to trust

## Source Of Truth Order

1. `docs/context/CURRENT.md`
2. `.context/active_task`
3. `docs/tasks/<task-id>.md`
4. `docs/context/PROJECT.md`
5. `docs/context/ARCHITECTURE.md`
6. `docs/context/CONVENTIONS.md`
7. `docs/context/DECISIONS.md` when the task or diff mentions prior decisions

`docs/context/CI_PROFILE.md` is intentionally outside the default read path. It stores project setup and CI policy so routine tasks do not pay to load it every session.

## Deliberate Design Choices

- One task contract file per request instead of brief/plan/handoff/run-log layers
- One active-task pointer instead of role-specific runtime state
- One approval gate before implementation instead of implicit “go ahead” assumptions
- Git diff plus content hashes instead of path-only baselines
- Verification and review receipts tied to the current task contract and current scoped diff
- Fail-closed completion: if the task changed after verification, completion is blocked

## Risk Modes

- `trivial`: tiny visual/config/text/value changes; still needs approval, but quality review is quick
- `standard`: default product work; needs explicit review on reuse, hardcoding, tests, and request alignment
- `high-risk`: payments, auth, permissions, destructive data changes, or other sensitive flows; adds explicit risk-controls review

## Folder Layout

```text
stable-ai-dev-template/
├── .github/
│   └── workflows/
│       └── ai-gate.yml
├── AGENTS.md
├── README.md
├── docs/
│   ├── context/
│   │   ├── ARCHITECTURE.md
│   │   ├── CI_PROFILE.md
│   │   ├── CONVENTIONS.md
│   │   ├── CURRENT.md
│   │   ├── DECISIONS.md
│   │   ├── PROJECT.md
│   │   └── TEMPLATE_IMPROVEMENT_POLICY.md
│   └── tasks/
│       ├── README.md
│       └── _template.md
├── scripts/
│   ├── _lib.sh
│   ├── approve-task.sh
│   ├── bootstrap-task.sh
│   ├── check-context.sh
│   ├── check-scope.sh
│   ├── check-task.sh
│   ├── ci/
│   │   ├── project-checks.sh
│   │   └── run-ai-gate.sh
│   ├── complete-task.sh
│   ├── log-decision.sh
│   ├── record-task-feedback.sh
│   ├── record-task-metrics.sh
│   ├── refresh-current.sh
│   ├── report-template-health.sh
│   ├── review-independent.sh
│   ├── review-quality.sh
│   ├── review-scope.sh
│   ├── run-task-checks.sh
│   ├── setup-ci-profile.sh
│   ├── start-task.sh
│   └── submit-task-plan.sh
├── test-guide.md
└── tests/
    └── smoke.sh
```

## Setup In A New Repository

1. Copy this folder into the repository root.
2. Customize:
   - `docs/context/PROJECT.md`
   - `docs/context/ARCHITECTURE.md`
   - `docs/context/CONVENTIONS.md`
3. Generate the CI profile:

```bash
bash scripts/setup-ci-profile.sh
```

The script asks for the project platform and framework, then writes recommended CI commands to `docs/context/CI_PROFILE.md`.
4. Review `docs/context/CI_PROFILE.md` and adjust any project-specific commands.
   - In `## PR Fast Checks`, `## High-Risk Checks`, and `## Full Project Checks`, keep entries command-only:
     - `- \`actual command\``
   - Put explanations and caveats in `## Notes`, not inside the command sections.
5. Run:

```bash
bash scripts/check-context.sh
```

The context check should fail until placeholders are replaced.

## Task Workflow

### 1. Create Or Activate A Task

```bash
bash scripts/bootstrap-task.sh <task-id>
```

This creates `docs/tasks/<task-id>.md` if it does not exist, captures a content-hash baseline for pre-existing dirty files, sets `.context/active_task`, and refreshes `docs/context/CURRENT.md`.

### 2. Fill The Task Contract

The task file is the only request-scoped source of truth.

It should define:

- risk level
- approval-ready plan
- goal
- non-goals
- requirements
- implementation plan
- target files
- out-of-scope areas
- scope guardrails
- reuse/config constraints
- risk controls
- acceptance
- verification commands
- review status
- session resume notes

### 3. Submit The Plan For Approval

```bash
bash scripts/submit-task-plan.sh <task-id>
```

This moves the task to `awaiting_approval`. Implementation must not start until the user approves the plan.

### 4. Record User Approval

```bash
bash scripts/approve-task.sh <task-id> --by "user" --note "approved the task plan"
bash scripts/start-task.sh <task-id>
```

This records who approved the work and opens the task for implementation.

### 5. Work Only Inside Scope

```bash
bash scripts/check-task.sh <task-id>
bash scripts/check-scope.sh <task-id>
```

If a file outside `## Target Files` must change, update the task contract before editing that file.

### 6. Run Verification

```bash
bash scripts/run-task-checks.sh <task-id>
```

This executes every command listed in `## Verification Commands`, writes a log, and stores a verification fingerprint that combines:

- the task contract's scope, plan, and acceptance sections
- the task contract's verification commands
- the current non-internal changed files and their content hashes

### 7. Review Scope And Quality

```bash
bash scripts/review-scope.sh <task-id> --summary "only approved files changed"
bash scripts/review-quality.sh <task-id> --summary "reused existing components and kept config centralized"
```

Review behavior depends on `risk-level`:

- `trivial`: summary-only quick review
- `standard`: requires explicit PASS on reuse, hardcoding, tests, and request-scope
- `high-risk`: standard review plus explicit PASS on risk-controls

Example for `standard` or `high-risk`:

```bash
bash scripts/review-quality.sh <task-id> \
  --summary "reused shared code and stayed inside the approved request" \
  --reuse pass \
  --hardcoding pass \
  --tests pass \
  --request-scope pass
```

### 8. Run An Independent Final Review

For `standard` and `high-risk` tasks, run one final code review through a separate context-free sub-agent before completion.

- The reviewer should read only the task contract, the approved target files, and the current diff.
- The reviewer should not reuse the implementation session context.
- Record the result with:

```bash
bash scripts/review-independent.sh <task-id> \
  --reviewer "context-free-subagent" \
  --summary "no findings; approved files only"
```

### 9. Refresh Resume Snapshot

```bash
bash scripts/refresh-current.sh <task-id>
```

Use this whenever the task status, next action, or changed-file set shifts enough that a new AI session should see the update immediately.

### 10. Record Important Decisions

```bash
bash scripts/log-decision.sh "Decision title" "What we decided" "Why we decided it"
```

Only log decisions that future sessions need to understand. Do not log routine edits.

### 11. Complete The Task

```bash
bash scripts/complete-task.sh <task-id> "<summary>" "<next-step>"
```

Completion re-checks context, task completeness, scope, verification freshness, and both review receipts. If the task or diff changed after verification or review, completion fails until checks are rerun.

### 12. After Merge: Local-Only Cleanup

Once the PR is merged, stop using tracked task state for merge housekeeping.

Do not:

- create a new `finalize-*` or `merge-cleanup-*` task
- edit `docs/context/CURRENT.md`
- edit `docs/tasks/*.md`
- leave merge-cleanup notes in tracked files

Allowed local-only cleanup:

- delete the remote branch if needed
- remove the local worktree if needed
- checkout `main`
- `git fetch --prune`
- `git pull`
- report unrelated pre-existing dirty files as unrelated residue

This keeps post-merge git cleanup from re-dirtying the repository with tracked workflow files.

## CI

This template ships with one GitHub Actions workflow:

- `.github/workflows/ai-gate.yml`

The workflow is intentionally split inside a single entrypoint:

- PRs: run the fast gate
- `high-risk` tasks: run the fast gate plus extra high-risk project checks
- manual full runs: run the fast gate plus full project checks

The fast gate always checks:

- context docs
- task contract validity
- task state must be `done`
- approval metadata exists
- changed files stay inside task scope
- task verification commands pass again in CI
- recorded review status is `PASS`
- for `standard` and `high-risk`, the independent review is `PASS`

Task detection in CI prefers:

1. `CI_TASK_ID`
2. `.context/active_task`
3. `docs/context/CURRENT.md`
4. exactly one changed task file

Project-specific CI setup lives in:

- `docs/context/CI_PROFILE.md`
- `scripts/ci/project-checks.sh`

Recommended use:

- keep `run_project_checks_for_pr_fast()` short
- use `run_project_checks_for_high_risk()` for expensive sensitive-flow checks
- reserve `run_project_checks_for_main()` for full project suites

## Template Health

The template records lightweight local metrics when a task completes.

- automatic local metrics: `bash scripts/record-task-metrics.sh <task-id>`
- optional feedback: `bash scripts/record-task-feedback.sh <task-id> --requirements-fit met --speed ok --accuracy high --satisfaction satisfied --note "..."` 
- summary report: `bash scripts/report-template-health.sh`

The metrics live under `.context/template-health/` and stay local by default.

Use them to spot repeated workflow friction such as slow tasks, frequent CI blockers, or low satisfaction.
Do not auto-edit the template from those metrics. Any template improvement still requires a dedicated change, a simple explanation, and explicit user approval first.

This keeps the required check on the PR only. Merge happens after the PR check passes; manual full runs remain available when you explicitly want them.

## Why This Stays Stable Across Context Resets

- `CURRENT.md` is always the first file to read
- `.context/active_task` points to the live contract immediately
- one task file contains all request-specific scope, approval, and verification rules
- decisions are separate from current state, so history does not bloat the resume path
- verification freshness is mechanical, not subjective
- unrelated edits are blocked both by target-file scope and by explicit task guardrails

## Smoke Test

Run:

```bash
bash tests/smoke.sh
```

It verifies the two most failure-prone behaviors in sustained AI workflows:

- implementation is blocked until approval is recorded
- unchanged pre-existing dirty files are ignored
- later edits to those same files are caught
- verification goes stale when the task contract changes
- stale verification and review receipts are rejected at completion
