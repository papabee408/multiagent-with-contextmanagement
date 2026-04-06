#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp -R "$TEMPLATE_DIR"/. "$TMP_DIR"/
cd "$TMP_DIR"

git init -q
git config user.name "Template Smoke"
git config user.email "template-smoke@example.com"

mkdir -p src tests

cat > docs/context/PROJECT.md <<'EOF'
# Project Context

## Identity
- project-name: Smoke Project
- repo-slug: smoke-project
- primary-users: maintainers

## Product Goal
- Prove the template enforces approval, scope, and review freshness.

## Constraints
- Keep the repo tiny.

## Quality Bar
- Fail closed when state is stale.
- Avoid unrelated edits.

## Critical Flows
- Approve the plan, implement inside scope, verify, review, and complete safely.
EOF

cat > docs/context/ARCHITECTURE.md <<'EOF'
# Architecture

## System Map
- entry/application: shell scripts
- domain/feature: small task-scoped source files
- infrastructure/integration: git and filesystem state
- shared: script helpers

## Module Boundaries
- Task workflow scripts orchestrate, source files stay simple.

## Dependency Rules
- allowed: scripts may inspect git state and task docs
- forbidden: hidden generated state outside .context/tasks

## Placement Rules
- new business logic: src/
- new IO or adapter code: scripts/
- new shared abstractions: scripts/_lib.sh
EOF

cat > docs/context/CONVENTIONS.md <<'EOF'
# Conventions

## Scope Discipline
- Only touch target files plus workflow internals.
- A target file does not authorize unrelated refactors or cleanup.

## Reuse And Config
- Reuse existing logic before adding variants.
- Keep configuration centralized.

## Testing
- Use deterministic shell checks for this smoke repo.
- Cover only the task behavior that changed.

## Visual Changes
- Preserve current visuals unless the request explicitly asks for a visual change.
EOF

cat > docs/context/CI_PROFILE.md <<'EOF'
# CI Profile

## Project Profile
- platform: web
- stack: shell-smoke
- package-manager: none
- setup-status: generated

## PR Fast Checks
- `bash tests/server-check.sh`

## High-Risk Checks
Keep engine-specific guidance in `test-guide.md`, not in this command list.

## Full Project Checks
- `bash tests/app-check.sh`
- `bash tests/server-check.sh`

## Notes
- Smoke repo uses shell commands only.
EOF

cat > src/app.sh <<'EOF'
#!/usr/bin/env bash
echo "button-size=4"
EOF

cat > src/server.sh <<'EOF'
#!/usr/bin/env bash
echo "api=v1"
EOF

cat > tests/app-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output="$(bash src/app.sh)"
if [[ "$output" != "button-size=8" ]]; then
  echo "[FAIL] unexpected output: $output" >&2
  exit 1
fi
EOF

cat > tests/server-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output="$(bash src/server.sh)"
if [[ "$output" != "api=v2" && "$output" != "api=v3" ]]; then
  echo "[FAIL] unexpected output: $output" >&2
  exit 1
fi
EOF

chmod +x scripts/*.sh scripts/ci/*.sh src/*.sh tests/*.sh

git add .
git commit -qm "initial-template-copy"

bash scripts/bootstrap-task.sh trivial-copy >/dev/null

cat > docs/tasks/trivial-copy.md <<'EOF'
# Task: trivial-copy

## Status
- state: planning
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-03-27 10:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Goal
- Update a tiny UI-adjacent value without touching unrelated files.

## Non-goals
- Do not refactor shell scripts or rewrite docs.

## Requirements
- RQ-001: Change the app output to the approved value.

## Implementation Plan
- Step 1: edit src/app.sh to emit the approved value
- Step 2: run the app verification command

## Target Files
- `src/app.sh`
- `tests/app-check.sh`

## Out of Scope
- src/server.sh and workflow docs must stay untouched.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse and Constraints
- existing abstractions to reuse: existing shell script and test
- config/constants to centralize: none
- side effects to avoid: touching unrelated files or changing runtime behavior outside the task

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- The approved value is emitted and the task completes with fresh verification and reviews.

## Verification Commands
- `bash tests/app-check.sh`

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-fingerprint: pending
- independent-review-status: pending
- independent-review-note: pending
- independent-reviewer: pending
- independent-review-fingerprint: pending
- independent-review-proof: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Session Resume
- current focus: finish the mini-plan and get approval
- next action: submit the plan for approval
- known risks: starting implementation before approval

## Completion
- summary: pending
- follow-up: pending
EOF

printf '%s\n' "trivial-copy" > .context/active_task

bash scripts/check-context.sh >/dev/null
bash scripts/check-task.sh trivial-copy >/dev/null
if bash scripts/start-task.sh trivial-copy >/dev/null 2>&1; then
  echo "[FAIL] start-task should fail before approval"
  exit 1
fi
if bash scripts/run-task-checks.sh trivial-copy >/dev/null 2>&1; then
  echo "[FAIL] verification should fail before approval and start"
  exit 1
fi

bash scripts/submit-task-plan.sh trivial-copy >/dev/null
bash scripts/approve-task.sh trivial-copy --by "user" --note "approved trivial value update" >/dev/null
if bash scripts/run-task-checks.sh trivial-copy >/dev/null 2>&1; then
  echo "[FAIL] verification should fail before the task is started"
  exit 1
fi

bash scripts/start-task.sh trivial-copy >/dev/null
perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
bash scripts/run-task-checks.sh trivial-copy >/dev/null
bash scripts/review-scope.sh trivial-copy --summary "only the approved tiny change landed" >/dev/null
bash scripts/review-quality.sh trivial-copy --summary "quick review: narrow change, no unrelated edits" >/dev/null
bash scripts/complete-task.sh trivial-copy "updated the approved tiny value" "no follow-up" >/dev/null

grep -Fq 'task-state: done' docs/context/CURRENT.md
git add .
git commit -qm "complete trivial task"

printf 'preexisting dirty\n' > notes.txt
bash scripts/bootstrap-task.sh scope-safety >/dev/null

cat > docs/tasks/scope-safety.md <<'EOF'
# Task: scope-safety

## Status
- state: planning
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-03-27 11:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Goal
- Update the server output without touching unrelated files.

## Non-goals
- Do not rename files, clean up helpers, or restyle anything else.

## Requirements
- RQ-001: Change the server output to the approved value.

## Implementation Plan
- Step 1: edit src/server.sh only for the requested output
- Step 2: run the server verification command

## Target Files
- `src/server.sh`
- `tests/server-check.sh`

## Out of Scope
- notes.txt and src/app.sh must stay outside task scope.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse and Constraints
- existing abstractions to reuse: existing server shell script and its test
- config/constants to centralize: none
- side effects to avoid: touching unrelated docs or notes.txt

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- Scope checks pass, reviews pass, and completion rejects stale verification or stale review state.

## Verification Commands
- `bash tests/server-check.sh`

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-fingerprint: pending
- independent-review-status: pending
- independent-review-note: pending
- independent-reviewer: pending
- independent-review-fingerprint: pending
- independent-review-proof: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Session Resume
- current focus: get approval, implement, then verify and review carefully
- next action: submit the plan for approval
- known risks: stale receipts and unrelated dirty files

## Completion
- summary: pending
- follow-up: pending
EOF

printf '%s\n' "scope-safety" > .context/active_task

bash scripts/check-task.sh scope-safety >/dev/null
bash scripts/submit-task-plan.sh scope-safety >/dev/null
bash scripts/approve-task.sh scope-safety --by "user" --note "approved standard task plan" >/dev/null
bash scripts/start-task.sh scope-safety >/dev/null

perl -0pi -e 's/api=v1/api=v2/' src/server.sh
bash scripts/check-scope.sh scope-safety >/dev/null

printf 'changed after baseline\n' >> notes.txt
if bash scripts/check-scope.sh scope-safety >/dev/null 2>&1; then
  echo "[FAIL] scope check should fail after notes.txt changes post-baseline"
  exit 1
fi
printf 'preexisting dirty\n' > notes.txt

bash scripts/run-task-checks.sh scope-safety >/dev/null
if bash scripts/complete-task.sh scope-safety "done" "none" >/dev/null 2>&1; then
  echo "[FAIL] complete-task should fail until reviews are recorded"
  exit 1
fi

perl -0pi -e 's#notes.txt and src/app.sh must stay outside task scope.#notes.txt and unrelated files must stay outside task scope.#' docs/tasks/scope-safety.md
if bash scripts/review-scope.sh scope-safety --summary "should fail because verification is stale" >/dev/null 2>&1; then
  echo "[FAIL] scope review should fail after the task contract changes"
  exit 1
fi

bash scripts/run-task-checks.sh scope-safety >/dev/null
bash scripts/review-scope.sh scope-safety --summary "only approved server files changed" >/dev/null
if bash scripts/review-quality.sh scope-safety --summary "missing standard review dimensions" >/dev/null 2>&1; then
  echo "[FAIL] quality review should fail without standard review dimensions"
  exit 1
fi
bash scripts/review-quality.sh scope-safety \
  --summary "reused the existing server script, added no hardcoding, kept the change aligned with the request" \
  --reuse pass \
  --hardcoding pass \
  --tests pass \
  --request-scope pass >/dev/null
if bash scripts/complete-task.sh scope-safety "done" "none" >/dev/null 2>&1; then
  echo "[FAIL] complete-task should fail until independent review is recorded"
  exit 1
fi

perl -0pi -e 's/api=v2/api=v3/' src/server.sh
if bash scripts/complete-task.sh scope-safety "updated server safely" "no follow-up" >/dev/null 2>&1; then
  echo "[FAIL] complete-task should reject stale verification and review receipts"
  exit 1
fi

bash scripts/run-task-checks.sh scope-safety >/dev/null
bash scripts/review-scope.sh scope-safety --summary "only approved files changed after the final tweak" >/dev/null
bash scripts/review-quality.sh scope-safety \
  --summary "final diff stays in request scope and keeps the implementation narrow" \
  --reuse pass \
  --hardcoding pass \
  --tests pass \
  --request-scope pass >/dev/null
bash scripts/review-independent.sh scope-safety \
  --reviewer "context-free-reviewer" \
  --summary "no findings; approved server files only" >/dev/null
bash scripts/complete-task.sh scope-safety "updated the approved server behavior safely" "no follow-up" >/dev/null
test -f "docs/tasks/.receipts/scope-safety/verification.receipt"
test -f "docs/tasks/.receipts/scope-safety/scope-review.receipt"
test -f "docs/tasks/.receipts/scope-safety/quality-review.receipt"
test -f "docs/tasks/.receipts/scope-safety/independent-review.receipt"

grep -Fq 'risk-level: standard' docs/context/CURRENT.md
grep -Fq 'quality-review: PASS' docs/context/CURRENT.md
grep -Fq 'scope-review: PASS' docs/context/CURRENT.md
grep -Fq 'independent-review: PASS' docs/context/CURRENT.md

rm -f notes.txt .context/active_task
git add .
git commit -qm "complete standard task"

if ! bash -lc 'source scripts/_lib.sh; source scripts/ci/project-checks.sh; run_project_checks_for_high_risk smoke' >/dev/null; then
  echo "[FAIL] high-risk project checks should ignore note prose inside CI profile sections"
  exit 1
fi

bash scripts/bootstrap-task.sh ci-fallback >/dev/null

cat > docs/tasks/ci-fallback.md <<'EOF'
# Task: ci-fallback

## Status
- state: planning
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-03-27 12:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Goal
- Prove CI can recover the active task from CURRENT.md when .context is absent.

## Non-goals
- Do not change app or server behavior.

## Requirements
- RQ-001: Update the task workflow readme without touching product files.

## Implementation Plan
- Step 1: edit docs/tasks/README.md with a tiny documentation note
- Step 2: rerun CI gate logic against the resulting diff

## Target Files
- `docs/tasks/README.md`

## Out of Scope
- src/, tests/, and workflow scripts must stay unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse and Constraints
- existing abstractions to reuse: existing task workflow docs
- config/constants to centralize: none
- side effects to avoid: product changes or unrelated workflow edits

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- AI Gate can infer the active task from CURRENT.md even when .context/active_task is missing.

## Verification Commands
- `bash tests/server-check.sh`

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-fingerprint: pending
- independent-review-status: pending
- independent-review-note: pending
- independent-reviewer: pending
- independent-review-fingerprint: pending
- independent-review-proof: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Session Resume
- current focus: close the CI fallback regression safely
- next action: submit the plan for approval
- known risks: CI may miss the active task when multiple task docs change

## Completion
- summary: pending
- follow-up: pending
EOF

bash scripts/check-task.sh ci-fallback >/dev/null
bash scripts/submit-task-plan.sh ci-fallback >/dev/null
bash scripts/approve-task.sh ci-fallback --by "user" --note "approved CI fallback regression fix" >/dev/null
bash scripts/start-task.sh ci-fallback >/dev/null
if bash scripts/record-task-metrics.sh ci-fallback >/dev/null 2>&1; then
  echo "[FAIL] task metrics should not record an in-progress task"
  exit 1
fi
printf '\n- Keep README updates narrow and task-scoped.\n' >> docs/tasks/README.md
bash scripts/run-task-checks.sh ci-fallback >/dev/null
bash scripts/review-scope.sh ci-fallback --summary "only the approved task docs changed" >/dev/null
bash scripts/review-quality.sh ci-fallback \
  --summary "kept the CI fallback regression fix documentation-only and inside scope" \
  --reuse pass \
  --hardcoding pass \
  --tests pass \
  --request-scope pass >/dev/null
bash scripts/review-independent.sh ci-fallback \
  --reviewer "context-free-reviewer" \
  --summary "no findings; CI fallback docs change stays inside scope" >/dev/null
bash scripts/complete-task.sh ci-fallback "documented the CI fallback regression safely" "no follow-up" >/dev/null
rm -f .context/active_task
git add .
git commit -qm "complete ci fallback task"

printf '%s\n' "scope-safety" > .context/active_task
CI_EVENT_NAME="pull_request" \
CI_DIFF_BASE="$(git rev-parse HEAD~1)" \
CI_DIFF_HEAD="$(git rev-parse HEAD)" \
bash scripts/ci/run-ai-gate.sh >/dev/null
rm -f .context/active_task

bash scripts/record-task-feedback.sh ci-fallback \
  --requirements-fit met \
  --speed ok \
  --accuracy high \
  --satisfaction satisfied \
  --note "smoke feedback recorded" >/dev/null

mv .context/template-health/task-metrics.tsv .context/template-health/task-metrics.tsv.bak
feedback_only_report="$(bash scripts/report-template-health.sh)"
printf '%s' "$feedback_only_report" | grep -Fq 'completed-tasks: 0'
printf '%s' "$feedback_only_report" | grep -Fq 'feedback-records: 1'
mv .context/template-health/task-metrics.tsv.bak .context/template-health/task-metrics.tsv

report_output="$(bash scripts/report-template-health.sh)"
printf '%s' "$report_output" | grep -Fq 'completed-tasks: 3'
printf '%s' "$report_output" | grep -Fq 'feedback-records: 1'

metrics_completed_at_before="$(awk -F'\t' '$2 == "ci-fallback" { print $13; exit }' .context/template-health/task-metrics.tsv)"
bash scripts/record-task-metrics.sh ci-fallback >/dev/null
metrics_completed_at_after="$(awk -F'\t' '$2 == "ci-fallback" { print $13; exit }' .context/template-health/task-metrics.tsv)"
if [[ "$metrics_completed_at_before" != "$metrics_completed_at_after" ]]; then
  echo "[FAIL] task metrics should preserve the original completed_at_utc on rerun"
  exit 1
fi
report_output="$(bash scripts/report-template-health.sh)"
printf '%s' "$report_output" | grep -Fq 'completed-tasks: 3'
printf '%s' "$report_output" | grep -Fq 'verification-pass-records: 3'
printf '%s' "$report_output" | grep -Fq 'scope-review-pass-records: 3'
printf '%s' "$report_output" | grep -Fq 'quality-review-pass-records: 3'
printf '%s' "$report_output" | grep -Fq 'independent-review-pass-records: 2'

printf '\n- stale post-review edit for CI regression coverage.\n' >> docs/tasks/README.md
git add docs/tasks/README.md
git commit -qm "stale review regression commit"

if CI_EVENT_NAME="pull_request" \
  CI_DIFF_BASE="$(git rev-parse HEAD~1)" \
  CI_DIFF_HEAD="$(git rev-parse HEAD)" \
  bash scripts/ci/run-ai-gate.sh >/dev/null 2>&1; then
  echo "[FAIL] ai-gate should reject stale review fingerprints after a post-completion edit"
  exit 1
fi

forged_fingerprint="$(bash -lc 'source scripts/_lib.sh; task_fingerprint ci-fallback')"
forged_proof="$(bash -lc "source scripts/_lib.sh; independent_review_proof_for_fingerprint ci-fallback \"$forged_fingerprint\" forged-reviewer forged")"
perl -0pi -e "s/- scope-review-note: .*/- scope-review-note: forged scope/; s/- scope-review-fingerprint: .*/- scope-review-fingerprint: $forged_fingerprint/; s/- quality-review-note: .*/- quality-review-note: forged quality/; s/- quality-review-fingerprint: .*/- quality-review-fingerprint: $forged_fingerprint/; s/- independent-review-status: .*/- independent-review-status: pass/; s/- independent-review-note: .*/- independent-review-note: forged/; s/- independent-reviewer: .*/- independent-reviewer: forged-reviewer/; s/- independent-review-fingerprint: .*/- independent-review-fingerprint: $forged_fingerprint/; s/- independent-review-proof: .*/- independent-review-proof: $forged_proof/" docs/tasks/ci-fallback.md
git add docs/tasks/ci-fallback.md
git commit -qm "forged independent review regression commit"

if CI_EVENT_NAME="pull_request" \
  CI_DIFF_BASE="$(git rev-parse HEAD~1)" \
  CI_DIFF_HEAD="$(git rev-parse HEAD)" \
  bash scripts/ci/run-ai-gate.sh >/dev/null 2>&1; then
  echo "[FAIL] ai-gate should reject forged independent review metadata"
  exit 1
fi

git branch -M main >/dev/null 2>&1 || true
git checkout -qb feature-merge-base >/dev/null

bash scripts/bootstrap-task.sh merge-base-scope >/dev/null

cat > docs/tasks/merge-base-scope.md <<'EOF'
# Task: merge-base-scope

## Status
- state: planning
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-03-27 13:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Goal
- Prove CI diffing ignores files changed only on the base branch.

## Non-goals
- Do not change product scripts or test behavior.

## Requirements
- RQ-001: Make one small docs/tasks README update and keep CI scope clean.

## Implementation Plan
- Step 1: update docs/tasks/README.md
- Step 2: validate AI Gate against a diverged base branch

## Target Files
- `docs/tasks/README.md`

## Out of Scope
- src/, tests/, scripts/, and base-only files must stay unchanged from the feature branch point of view.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse and Constraints
- existing abstractions to reuse: current task docs
- config/constants to centralize: none
- side effects to avoid: changes outside docs/tasks/README.md

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- AI Gate passes even if main has unrelated newer changes.

## Verification Commands
- `bash tests/server-check.sh`

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-fingerprint: pending
- independent-review-status: pending
- independent-review-note: pending
- independent-reviewer: pending
- independent-review-fingerprint: pending
- independent-review-proof: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Session Resume
- current focus: finish the merge-base regression proof
- next action: submit the plan for approval
- known risks: base-branch-only files could leak into CI scope checks

## Completion
- summary: pending
- follow-up: pending
EOF

bash scripts/check-task.sh merge-base-scope >/dev/null
bash scripts/submit-task-plan.sh merge-base-scope >/dev/null
bash scripts/approve-task.sh merge-base-scope --by "user" --note "approved merge-base regression proof" >/dev/null
bash scripts/start-task.sh merge-base-scope >/dev/null
printf '\n- Merge-base CI diffing is required for clean PR scope checks.\n' >> docs/tasks/README.md
bash scripts/run-task-checks.sh merge-base-scope >/dev/null
bash scripts/review-scope.sh merge-base-scope --summary "only the approved task docs changed on the feature branch" >/dev/null
bash scripts/review-quality.sh merge-base-scope --summary "quick review: narrow docs-only regression proof" >/dev/null
bash scripts/complete-task.sh merge-base-scope "documented the merge-base regression proof" "no follow-up" >/dev/null
git add .
git commit -qm "complete merge-base scope task"

git checkout -q main
printf 'base-only\n' > base-only.txt
git add base-only.txt
git commit -qm "base branch change"

git checkout -q feature-merge-base
rm -f .context/active_task
CI_EVENT_NAME="pull_request" \
CI_DIFF_BASE="main" \
CI_DIFF_HEAD="$(git rev-parse HEAD)" \
bash scripts/ci/run-ai-gate.sh >/dev/null

bash scripts/bootstrap-task.sh high-risk-chain >/dev/null

cat > docs/tasks/high-risk-chain.md <<'EOF'
# Task: high-risk-chain

## Status
- state: planning
- owner: ai
- risk-level: high-risk
- updated-at-utc: 2026-03-27 14:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Goal
- Prove the full high-risk review and CI chain works end to end.

## Non-goals
- Do not touch product scripts, tests, or archive paths.

## Requirements
- RQ-001: Add one narrow workflow doc note and require the full high-risk review sequence.

## Implementation Plan
- Step 1: update docs/tasks/README.md with one high-risk workflow note
- Step 2: run verification, reviews, and AI Gate on the final diff

## Target Files
- `docs/tasks/README.md`

## Out of Scope
- src/, tests/, scripts/, and archive paths must stay unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse and Constraints
- existing abstractions to reuse: current task workflow docs
- config/constants to centralize: none
- side effects to avoid: changes outside the approved docs file

## Risk Controls
- sensitive areas touched: ci/task workflow gate behavior
- extra checks before merge: pass independent review and risk-controls review before completion

## Acceptance
- High-risk review fields and AI Gate both pass on the final diff.

## Verification Commands
- `bash tests/server-check.sh`

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-fingerprint: pending
- independent-review-status: pending
- independent-review-note: pending
- independent-reviewer: pending
- independent-review-fingerprint: pending
- independent-review-proof: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Session Resume
- current focus: prove the full high-risk chain end to end
- next action: submit the plan for approval
- known risks: missing risk-controls review would leave the high-risk path under-tested

## Completion
- summary: pending
- follow-up: pending
EOF

bash scripts/check-task.sh high-risk-chain >/dev/null
bash scripts/submit-task-plan.sh high-risk-chain >/dev/null
bash scripts/approve-task.sh high-risk-chain --by "user" --note "approved high-risk chain regression proof" >/dev/null
bash scripts/start-task.sh high-risk-chain >/dev/null
printf '\n- High-risk tasks require an independent final review before completion.\n' >> docs/tasks/README.md
bash scripts/run-task-checks.sh high-risk-chain >/dev/null
bash scripts/review-scope.sh high-risk-chain --summary "only the approved docs/tasks README update landed" >/dev/null
bash scripts/review-quality.sh high-risk-chain \
  --summary "kept the high-risk regression proof narrow, reused existing docs, and recorded the required risk controls" \
  --reuse pass \
  --hardcoding pass \
  --tests pass \
  --request-scope pass \
  --risk-controls pass >/dev/null
bash scripts/review-independent.sh high-risk-chain \
  --reviewer "context-free-reviewer" \
  --summary "no findings; high-risk chain stays docs-only and records the extra controls" >/dev/null
bash scripts/complete-task.sh high-risk-chain "proved the full high-risk review and CI chain" "no follow-up" >/dev/null
git add .
git commit -qm "complete high-risk review chain task"
rm -f .context/active_task
CI_EVENT_NAME="pull_request" \
CI_DIFF_BASE="$(git rev-parse HEAD~1)" \
CI_DIFF_HEAD="$(git rev-parse HEAD)" \
bash scripts/ci/run-ai-gate.sh >/dev/null

echo "[PASS] stable-ai-dev-template smoke"
