#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
if [[ "${KEEP_SMOKE_TMP:-0}" != "1" ]]; then
  trap 'rm -rf "$TMP_DIR"' EXIT
else
  echo "[INFO] keeping smoke temp dir: $TMP_DIR" >&2
fi

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq "$needle" "$file" || fail "expected '$needle' in $file"
}

expect_failure() {
  local label="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    fail "$label"
  fi
}

setup_fake_gh() {
  mkdir -p "$TMP_DIR/bin"
  cat > "$TMP_DIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${FAKE_GH_STATE_DIR:?}"
mkdir -p "$STATE_DIR/prs"

pr_file_for_number() {
  printf '%s/prs/%s.json' "$STATE_DIR" "$1"
}

all_pr_files() {
  find "$STATE_DIR/prs" -type f -name '*.json' 2>/dev/null | sort -V
}

find_open_pr_file_by_head() {
  local head="$1"
  local file

  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if [[ "$(jq -r '.head' "$file")" == "$head" && "$(jq -r '.open' "$file")" == "true" ]]; then
      printf '%s' "$file"
      return 0
    fi
  done < <(all_pr_files)

  return 1
}

current_sha_for_ref() {
  git rev-parse "$1" 2>/dev/null || true
}

emit_pr_json() {
  local file="$1"
  local number base head draft open body url head_sha

  number="$(jq -r '.number' "$file")"
  base="$(jq -r '.base' "$file")"
  head="$(jq -r '.head' "$file")"
  draft="$(jq -r '.draft' "$file")"
  open="$(jq -r '.open' "$file")"
  body="$(jq -r '.body' "$file")"
  url="$(jq -r '.url' "$file")"
  head_sha="$(current_sha_for_ref "$head")"
  if [[ -z "$head_sha" ]]; then
    head_sha="$(jq -r '.head_sha' "$file")"
  fi

  jq -n \
    --argjson number "$number" \
    --argjson isOpen "$open" \
    --argjson isDraft "$draft" \
    --arg baseRefName "$base" \
    --arg headRefName "$head" \
    --arg headRefOid "$head_sha" \
    --arg body "$body" \
    --arg url "$url" \
    '{
      number: $number,
      isOpen: $isOpen,
      isDraft: $isDraft,
      baseRefName: $baseRefName,
      headRefName: $headRefName,
      headRefOid: $headRefOid,
      body: $body,
      url: $url
    }'
}

next_pr_number() {
  local file="$STATE_DIR/next-pr-number"

  if [[ ! -f "$file" ]]; then
    echo "2" > "$file"
    printf '1'
    return 0
  fi

  local next
  next="$(cat "$file")"
  echo "$((next + 1))" > "$file"
  printf '%s' "$next"
}

log_event() {
  printf '%s\n' "$1" >> "$STATE_DIR/gh.log"
}

case "${1:-}" in
  pr)
    shift
    case "${1:-}" in
      view)
        shift
        selector="${1:-}"
        shift || true

        jq_expr=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json)
              shift 2
              ;;
            --jq)
              jq_expr="${2:-}"
              shift 2
              ;;
            *)
              shift
              ;;
          esac
        done

        if [[ "$selector" =~ ^[0-9]+$ ]]; then
          file="$(pr_file_for_number "$selector")"
        else
          file="$(find_open_pr_file_by_head "$selector" || true)"
        fi

        [[ -f "${file:-}" ]] || exit 1

        if [[ "$jq_expr" == ".number" ]]; then
          jq -r '.number' "$file"
          exit 0
        fi

        emit_pr_json "$file"
        ;;
      create)
        shift
        base=""
        head=""
        draft="false"
        body_file=""

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --base)
              base="${2:-}"
              shift 2
              ;;
            --head)
              head="${2:-}"
              shift 2
              ;;
            --draft)
              draft="true"
              shift
              ;;
            --body-file)
              body_file="${2:-}"
              shift 2
              ;;
            --fill)
              shift
              ;;
            *)
              shift
              ;;
          esac
        done

        [[ -n "$base" && -n "$head" && -n "$body_file" ]] || exit 1

        existing="$(find_open_pr_file_by_head "$head" || true)"
        if [[ -n "$existing" ]]; then
          emit_pr_json "$existing"
          exit 0
        fi

        number="$(next_pr_number)"
        body="$(cat "$body_file")"
        head_sha="$(current_sha_for_ref "$head")"
        url="https://example.test/pr/$number"
        file="$(pr_file_for_number "$number")"

        jq -n \
          --argjson number "$number" \
          --arg base "$base" \
          --arg head "$head" \
          --arg body "$body" \
          --arg url "$url" \
          --arg head_sha "$head_sha" \
          --argjson draft "$draft" \
          '{
            number: $number,
            base: $base,
            head: $head,
            body: $body,
            url: $url,
            head_sha: $head_sha,
            draft: $draft,
            open: true
          }' > "$file"

        log_event "pr-create:$head"
        emit_pr_json "$file"
        ;;
      edit)
        shift
        selector="${1:-}"
        shift || true
        body_file=""

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --body-file)
              body_file="${2:-}"
              shift 2
              ;;
            *)
              shift
              ;;
          esac
        done

        [[ -n "$selector" && -n "$body_file" ]] || exit 1
        file="$(pr_file_for_number "$selector")"
        [[ -f "$file" ]] || exit 1

        tmp="$(mktemp)"
        jq \
          --arg body "$(cat "$body_file")" \
          --arg head_sha "$(current_sha_for_ref "$(jq -r '.head' "$file")")" \
          '.body = $body | .head_sha = $head_sha' \
          "$file" > "$tmp"
        mv "$tmp" "$file"

        log_event "pr-edit:$selector"
        emit_pr_json "$file"
        ;;
      merge)
        shift
        selector="${1:-}"
        shift || true
        delete_branch="false"

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --delete-branch)
              delete_branch="true"
              shift
              ;;
            --squash|--merge|--rebase)
              shift
              ;;
            *)
              shift
              ;;
          esac
        done

        file="$(pr_file_for_number "$selector")"
        [[ -f "$file" ]] || exit 1

        base="$(jq -r '.base' "$file")"
        head="$(jq -r '.head' "$file")"
        head_sha="$(current_sha_for_ref "$head")"

        git push origin "$head:refs/heads/$base" >/dev/null
        if [[ "$delete_branch" == "true" ]]; then
          git push origin --delete "$head" >/dev/null 2>&1 || true
        fi

        tmp="$(mktemp)"
        jq \
          --arg head_sha "$head_sha" \
          '.open = false | .draft = false | .head_sha = $head_sha' \
          "$file" > "$tmp"
        mv "$tmp" "$file"

        log_event "pr-merge:$selector"
        printf 'Merged pull request #%s\n' "$selector"
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  api)
    shift
    endpoint="${1:-}"
    shift || true

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --jq)
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done

    case "$endpoint" in
      */branches/*/protection)
        [[ -f "$STATE_DIR/required-checks.txt" ]] && cat "$STATE_DIR/required-checks.txt"
        ;;
      */commits/*/check-runs)
        sha="${endpoint#*/commits/}"
        sha="${sha%%/check-runs}"
        check_file="$STATE_DIR/checks_$sha.txt"
        if [[ -f "$check_file" ]]; then
          jq -Rn '[inputs | select(length > 0) | {name: ., status: "completed", conclusion: "success"}] | {check_runs: .}' < "$check_file"
        else
          echo '{"check_runs":[]}'
        fi
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$TMP_DIR/bin/gh"
  export PATH="$TMP_DIR/bin:$PATH"
}

write_context_files() {
  cat > docs/context/PROJECT.md <<'EOF'
# Project Context

## Identity
- project-name: Smoke Project
- repo-slug: smoke-project
- primary-users: maintainers

## Product Goal
- Prove the template enforces task scope, approval, publish-late rules, and PR automation safely.

## Constraints
- Keep the repo intentionally small and shell-only.

## Quality Bar
- Fail closed when verification or review state is stale.
- Prefer narrow task-scoped diffs over unrelated cleanup.
- Treat Task-ID and file scope mismatches as blockers.

## Critical Flows
- Approve work, implement inside scope, verify, review, publish, and merge with explicit task tracking.
EOF

  cat > docs/context/ARCHITECTURE.md <<'EOF'
# Architecture

## System Map
- entry/application: shell scripts in src/
- domain/feature: task-scoped behavior changes
- infrastructure/integration: git, fake GitHub CLI, and runtime state under .context/
- shared: workflow scripts and helpers

## Module Boundaries
- Source files in src/ expose the tiny behavior under test.
- Workflow scripts own task state and PR automation.

## Dependency Rules
- allowed: scripts may inspect git state, docs, and fake GitHub responses
- forbidden: generated state outside .context/ and implicit task metadata outside docs/tasks

## Placement Rules
- new business logic: src/
- new IO or adapter code: scripts/
- new shared abstractions: scripts/_lib.sh
EOF

  cat > docs/context/CONVENTIONS.md <<'EOF'
# Conventions

## Scope Discipline
- No implementation work before approval and start-task.
- Only change target files plus workflow internal files.
- A target file is not a license for unrelated cleanup or refactoring.
- If scope grows, update the task before editing new non-internal files.

## Reuse And Config
- Reuse the existing shell scripts before adding variants.
- Keep test constants inside the purpose-built smoke checks.
- Do not scatter task metadata outside the task file and CURRENT snapshot.

## Testing
- Use deterministic shell checks only.
- Verification commands should validate the exact approved behavior change.
- CI reruns task verification and project fast checks.

## Visual Changes
- No visual changes in this smoke repo.
EOF

  cat > docs/context/CI_PROFILE.md <<'EOF'
# CI Profile

## Project Profile
- platform: shell
- stack: task-driven-smoke
- package-manager: none
- setup-status: generated

## Git / PR Policy
- git-host: github
- default-base-branch: main
- default-branch-strategy: publish-late
- task-branch-pattern: task/<task-id>
- required-check-resolution: branch-protection-first
- merge-method: squash

## Required Check Fallback
- `AI Gate`

## PR Fast Checks
- `bash tests/project-fast-check.sh`

## High-Risk Checks
- `bash tests/project-high-risk-check.sh`

## Full Project Checks
- `bash tests/project-full-check.sh`

## Notes
- The smoke repo uses a fake gh binary and local bare git remotes only.
EOF
}

write_project_files() {
  mkdir -p src tests

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
[[ "$output" == "button-size=8" ]]
EOF

  cat > tests/server-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output="$(bash src/server.sh)"
[[ "$output" == "api=v2" ]]
EOF

  cat > tests/project-fast-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test -f docs/context/CURRENT.md
EOF

  cat > tests/project-high-risk-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test -f docs/context/CI_PROFILE.md
EOF

  cat > tests/project-full-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test -f docs/tasks/_template.md
EOF
}

setup_repo() {
  local name="$1"
  local repo="$TMP_DIR/repos/$name"
  local remote="$TMP_DIR/remotes/$name.git"
  local gh_state="$TMP_DIR/gh-state/$name"

  mkdir -p "$TMP_DIR/repos" "$TMP_DIR/remotes" "$gh_state"
  mkdir -p "$repo"
  (
    cd "$TEMPLATE_DIR"
    tar \
      --exclude=".git" \
      --exclude=".context" \
      --exclude="migration-archive" \
      --exclude="stable-ai-dev-template" \
      --exclude="codex-template-multi-agent-process" \
      -cf - .
  ) | (
    cd "$repo"
    tar -xf -
  )

  (
    cd "$repo"
    git init -q
    git config user.name "Template Smoke"
    git config user.email "template-smoke@example.com"
    git checkout -qb main

    write_context_files
    write_project_files

    chmod +x scripts/*.sh scripts/ci/*.sh tests/*.sh src/*.sh

    git add .
    git commit -qm "initial smoke repo"

    git init --bare -q "$remote"
    git remote add origin "$remote"
    git push -u origin main >/dev/null
  )

  printf 'AI Gate\n' > "$gh_state/required-checks.txt"

  export FAKE_GH_STATE_DIR="$gh_state"
  export GITHUB_REPO_PATH_OVERRIDE="repos/example/$name"
  export CURRENT_SMOKE_REPO="$repo"
}

mark_check_success() {
  local sha="$1"
  local check_name="$2"
  printf '%s\n' "$check_name" > "$FAKE_GH_STATE_DIR/checks_$sha.txt"
}

assert_branch_absent() {
  local repo="$1"
  local branch="$2"
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
    fail "expected local branch '$branch' to be deleted"
  fi
}

assert_split_guidance_present() {
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" "이 요청은 기능이 여러 개 섞여 있어서 한 번에 묶는 것보다 나눠서 처리하는 편이 더 빠릅니다."
  assert_file_contains "$TEMPLATE_DIR/README.md" "이유는 검증, PR 리뷰, merge, 후속 수정까지 전체 리드타임이 줄기 때문입니다."
}

scenario_scope_and_approval() {
  setup_repo "scope-and-approval"
  cd "$CURRENT_SMOKE_REPO"

  printf 'preexisting dirty\n' > notes.txt
  bash scripts/bootstrap-task.sh scope-safety >/dev/null

  cat > docs/tasks/scope-safety.md <<'EOF'
# Task: scope-safety

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-04-07 00:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one narrow user-visible output change
- bundle-override-approved: no

## Goal
- Update the app output to the approved button size only.

## Non-goals
- Do not touch server behavior, PR workflow, or unrelated docs.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.

## Implementation Plan
- Step 1: update `src/app.sh`.
- Step 2: run the app verification command.

## Target Files
- `src/app.sh`

## Out of Scope
- `src/server.sh`, task splitting policy, and merge automation remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script and smoke check.
- config/constants to centralize: none
- side effects to avoid: changing server behavior or unrelated workflow files.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- The app check passes and the task completes with fresh verification and reviews.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending
- verification-fingerprint: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- quality-review-fingerprint: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: required

## Session Resume
- current focus: finish the plan and get approval.
- next action: submit the task plan for approval.
- known risks: starting implementation before approval or touching unrelated files.

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/check-context.sh >/dev/null
  bash scripts/check-task.sh scope-safety >/dev/null
  expect_failure "start-task should fail before approval" bash scripts/start-task.sh scope-safety
  expect_failure "verification should fail before approval" bash scripts/run-task-checks.sh scope-safety

  bash scripts/submit-task-plan.sh scope-safety >/dev/null
  bash scripts/approve-task.sh scope-safety --by "user" --note "approved narrow app change" >/dev/null
  expect_failure "verification should fail before start-task" bash scripts/run-task-checks.sh scope-safety

  bash scripts/start-task.sh scope-safety >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh

  bash scripts/check-scope.sh scope-safety >/dev/null
  printf 'new unrelated file\n' > stray.txt
  expect_failure "check-scope should fail for new unrelated files after baseline" bash scripts/check-scope.sh scope-safety
  rm -f stray.txt

  bash scripts/run-task-checks.sh scope-safety >/dev/null
  bash scripts/review-scope.sh scope-safety --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh scope-safety --summary "quick review: narrow change and deterministic check" >/dev/null
  bash scripts/complete-task.sh scope-safety "updated the approved app output" "create a task branch before publish if this task needs a PR" >/dev/null

  assert_file_contains docs/context/CURRENT.md "task-state: done"
  assert_file_contains docs/context/CURRENT.md "verification-status: pass"
  test -f .context/tasks/scope-safety/verification.receipt || fail "missing runtime verification receipt"
}

scenario_publish_late_commit_rejection() {
  setup_repo "publish-late-commit-rejection"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh main-commit-guard >/dev/null

  cat > docs/tasks/main-commit-guard.md <<'EOF'
# Task: main-commit-guard

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-04-07 00:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one app output change only
- bundle-override-approved: no

## Goal
- Update the app output while staying on the publish-late path.

## Non-goals
- Do not create a PR or touch server behavior.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.

## Implementation Plan
- Step 1: update `src/app.sh`.
- Step 2: run the app verification command.

## Target Files
- `src/app.sh`

## Out of Scope
- `src/server.sh` and merge automation remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script and check.
- config/constants to centralize: none
- side effects to avoid: base-branch commits and unrelated file changes.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- The task guard rejects local commits on the base branch.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending
- verification-fingerprint: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- quality-review-fingerprint: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: required

## Session Resume
- current focus: get approval for the narrow app change.
- next action: submit the task plan for approval.
- known risks: committing on main before creating the task branch.

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh main-commit-guard >/dev/null
  bash scripts/approve-task.sh main-commit-guard --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh main-commit-guard >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh

  git add src/app.sh docs/tasks/main-commit-guard.md docs/context/CURRENT.md
  git commit -qm "task(main-commit-guard): incorrect main branch commit"

  expect_failure "publish-late should reject local commits on the base branch" bash scripts/run-task-checks.sh main-commit-guard
}

scenario_publish_and_merge() {
  setup_repo "publish-and-merge"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh publish-late-flow >/dev/null

  cat > docs/tasks/publish-late-flow.md <<'EOF'
# Task: publish-late-flow

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-07 00:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one server behavior change only
- bundle-override-approved: no

## Goal
- Update the server output to `api=v2` and publish the change through one task branch and one PR.

## Non-goals
- Do not change the app output or bundle another feature.

## Requirements
- RQ-001: `src/server.sh` must emit `api=v2`.

## Implementation Plan
- Step 1: update `src/server.sh`.
- Step 2: run verification.
- Step 3: review, complete, publish, and merge through the task branch.

## Target Files
- `src/server.sh`

## Out of Scope
- `src/app.sh`, multiple-task intake, and unrelated docs remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing server shell script and smoke check.
- config/constants to centralize: none
- side effects to avoid: unrelated app changes or bundled task files.

## Risk Controls
- sensitive areas touched: server output contract used by the smoke check.
- extra checks before merge: rerun the required AI Gate check on the latest PR head SHA.

## Acceptance
- The server check passes, the PR carries Task-ID metadata, and merge syncs local main cleanly.

## Verification Commands
- `bash tests/server-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending
- verification-fingerprint: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- quality-review-fingerprint: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: required

## Session Resume
- current focus: finish the plan and get approval.
- next action: submit the task plan for approval.
- known risks: publishing before the branch and commit boundary are explicit.

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/check-context.sh >/dev/null
  bash scripts/submit-task-plan.sh publish-late-flow >/dev/null
  bash scripts/approve-task.sh publish-late-flow --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh publish-late-flow >/dev/null
  perl -0pi -e 's/api=v1/api=v2/' src/server.sh

  bash scripts/run-task-checks.sh publish-late-flow >/dev/null
  bash scripts/review-scope.sh publish-late-flow --summary "scope stayed inside src/server.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh publish-late-flow \
    --summary "reviewed reuse, hardcoding, tests, and request scope for the server change" \
    --reuse pass \
    --hardcoding pass \
    --tests pass \
    --request-scope pass >/dev/null
  bash scripts/complete-task.sh publish-late-flow \
    "updated the approved server output" \
    "create or switch to task/publish-late-flow, commit the approved diff, then publish the PR" >/dev/null

  CI_DIFF_BASE="missing-base-ref" CI_DIFF_HEAD="missing-head-ref" bash scripts/check-task.sh publish-late-flow >/dev/null

  git switch -c task/publish-late-flow >/dev/null
  expect_failure "open-task-pr should fail on a dirty task branch" bash scripts/open-task-pr.sh publish-late-flow

  git add src/server.sh docs/tasks/publish-late-flow.md docs/context/CURRENT.md
  git commit -qm "task(publish-late-flow): initial publish"

  bash scripts/open-task-pr.sh publish-late-flow >/dev/null

  PR_NUMBER="$(gh pr view task/publish-late-flow --json number --jq '.number')"
  [[ -n "$PR_NUMBER" ]] || fail "expected PR number after initial publish"
  PR_BODY="$(gh pr view "$PR_NUMBER" --json body | jq -r '.body')"
  printf '%s\n' "$PR_BODY" | grep -Fq 'Task-ID: publish-late-flow' || fail "missing Task-ID metadata in PR body"

  perl -0pi -e 's/- follow-up: .*/- follow-up: publish update documented after initial PR creation/' docs/tasks/publish-late-flow.md
  bash scripts/check-task.sh publish-late-flow >/dev/null
  bash scripts/refresh-current.sh publish-late-flow >/dev/null
  git add docs/tasks/publish-late-flow.md docs/context/CURRENT.md
  git commit -qm "task(publish-late-flow): update mutable summary"

  bash scripts/open-task-pr.sh publish-late-flow >/dev/null
  grep -Eq '^pr-edit:[0-9]+$' "$FAKE_GH_STATE_DIR/gh.log" || fail "expected PR updates to target a numeric PR id"

  PR_BODY="$(gh pr view "$PR_NUMBER" --json body | jq -r '.body')"
  rm -rf .context/tasks
  CI_PR_BODY="$PR_BODY" CI_DIFF_BASE="origin/main" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh >/dev/null

  HEAD_SHA="$(gh pr view "$PR_NUMBER" --json headRefOid | jq -r '.headRefOid')"
  mark_check_success "$HEAD_SHA" "AI Gate"

  bash scripts/merge-task-pr.sh publish-late-flow >/dev/null

  [[ "$(git branch --show-current)" == "main" ]] || fail "expected merge-task-pr to return to main"
  [[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] || fail "expected local main to sync with origin/main"
  assert_branch_absent "$CURRENT_SMOKE_REPO" "task/publish-late-flow"
  assert_file_contains docs/context/CURRENT.md "active-task: none"
}

scenario_intake_validation() {
  setup_repo "intake-validation"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh bundled-request >/dev/null

  cat > docs/tasks/bundled-request.md <<'EOF'
# Task: bundled-request

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-04-07 00:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 2
- split-decision: single-task
- split-rationale: bundled by mistake
- bundle-override-approved: no

## Goal
- Bundle two unrelated features in one task.

## Non-goals
- None.

## Requirements
- RQ-001: change the app output.

## Implementation Plan
- Step 1: change one thing.

## Target Files
- `src/app.sh`

## Out of Scope
- Server behavior.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: existing shell script.
- config/constants to centralize: none
- side effects to avoid: mixing unrelated features.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- The validation catches the bundled intake issue.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending
- verification-fingerprint: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- quality-review-fingerprint: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: required

## Session Resume
- current focus: validate intake.
- next action: run check-task.
- known risks: the intake metadata is intentionally invalid.

## Completion
- summary: pending
- follow-up: pending
EOF

  expect_failure "multi-cluster tasks should not pass as single-task" bash scripts/check-task.sh bundled-request
  perl -0pi -e 's/- split-decision: single-task/- split-decision: user-bundled/' docs/tasks/bundled-request.md
  expect_failure "bundled multi-cluster tasks require explicit override approval" bash scripts/check-task.sh bundled-request
  perl -0pi -e 's/- bundle-override-approved: no/- bundle-override-approved: yes/' docs/tasks/bundled-request.md
  expect_failure "bundled multi-cluster tasks cannot stay trivial risk" bash scripts/check-task.sh bundled-request
}

scenario_ci_metadata_mismatch() {
  setup_repo "ci-metadata-mismatch"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh ci-mismatch >/dev/null

  cat > docs/tasks/ci-mismatch.md <<'EOF'
# Task: ci-mismatch

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-04-07 00:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one app output change only
- bundle-override-approved: no

## Goal
- Update the app output and publish it with one task id.

## Non-goals
- Do not add another live task to the same PR.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.

## Implementation Plan
- Step 1: update `src/app.sh`.
- Step 2: verify, review, and publish the task.

## Target Files
- `src/app.sh`

## Out of Scope
- Additional task files and server behavior.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script and check.
- config/constants to centralize: none
- side effects to avoid: adding extra task files to the PR.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- CI should reject a PR when the Task-ID metadata no longer matches the changed task files.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending
- verification-fingerprint: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- scope-review-fingerprint: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- quality-review-fingerprint: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- risk-controls-review: pending

## Git / PR
- base-branch: main
- branch-strategy: publish-late
- pr-metadata-policy: required

## Session Resume
- current focus: complete the app task cleanly.
- next action: submit the task plan for approval.
- known risks: mixing another task file into the same PR later.

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh ci-mismatch >/dev/null
  bash scripts/approve-task.sh ci-mismatch --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh ci-mismatch >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  bash scripts/run-task-checks.sh ci-mismatch >/dev/null
  bash scripts/review-scope.sh ci-mismatch --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh ci-mismatch --summary "quick review: narrow change and deterministic check" >/dev/null
  bash scripts/complete-task.sh ci-mismatch "updated the approved app output" "publish from the task branch" >/dev/null

  git switch -c task/ci-mismatch >/dev/null
  git add src/app.sh docs/tasks/ci-mismatch.md docs/context/CURRENT.md
  git commit -qm "task(ci-mismatch): initial publish"
  bash scripts/open-task-pr.sh ci-mismatch >/dev/null

  PR_NUMBER="$(gh pr view task/ci-mismatch --json number --jq '.number')"
  PR_BODY="$(gh pr view "$PR_NUMBER" --json body | jq -r '.body')"

  bash scripts/bootstrap-task.sh other-task >/dev/null
  git add docs/tasks/other-task.md docs/context/CURRENT.md
  git commit -qm "chore: add a second live task file to the PR"

  expect_failure "CI should reject PR metadata when changed task files no longer match Task-ID" env CI_PR_BODY="$PR_BODY" CI_DIFF_BASE="origin/main" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh
}

setup_fake_gh
assert_split_guidance_present

scenario_scope_and_approval
scenario_publish_late_commit_rejection
scenario_publish_and_merge
scenario_intake_validation
scenario_ci_metadata_mismatch

echo "[PASS] smoke"
