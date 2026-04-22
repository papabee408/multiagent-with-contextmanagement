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
  grep -Fq -- "$needle" "$file" || fail "expected '$needle' in $file"
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
  local number base head draft open merged body url head_sha

  number="$(jq -r '.number' "$file")"
  base="$(jq -r '.base' "$file")"
  head="$(jq -r '.head' "$file")"
  draft="$(jq -r '.draft' "$file")"
  open="$(jq -r '.open' "$file")"
  merged="$(jq -r '.merged // false' "$file")"
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
    --arg state "$(if [[ "$merged" == "true" ]]; then printf '%s' "MERGED"; elif [[ "$open" == "true" ]]; then printf '%s' "OPEN"; else printf '%s' "CLOSED"; fi)" \
    --arg baseRefName "$base" \
    --arg headRefName "$head" \
    --arg headRefOid "$head_sha" \
    --arg body "$body" \
    --arg url "$url" \
    '{
      number: $number,
      isOpen: $isOpen,
      isDraft: $isDraft,
      state: $state,
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
            open: true,
            merged: false
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
          '.open = false | .draft = false | .merged = true | .head_sha = $head_sha' \
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
- Treat unresolved task identity and real scope violations as blockers.
- Recover missing PR metadata automatically when the task and diff are otherwise valid.

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

  cat > docs/context/RESUME_GUIDE.md <<'EOF'
# Resume Guide

## File Roles
- explicit task id or current task branch: local task selection rule
- `bash scripts/status-task.sh [task-id]`: local status surface
- `docs/tasks/<task-id>.md`: canonical tracked task contract and state
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
test -f docs/context/RESUME_GUIDE.md
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
  bash "$TEMPLATE_DIR/scripts/export-stable-template.sh" "$repo" >/dev/null

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

setup_exported_bundle_repo() {
  local name="$1"
  local repo="$TMP_DIR/repos/$name"

  mkdir -p "$TMP_DIR/repos"
  bash "$TEMPLATE_DIR/scripts/export-stable-template.sh" "$repo" >/dev/null

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
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" 'If the task is already `review` and the feedback only addresses review findings'
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" "Never append a materially new follow-up request to a task already in"
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" "open a new task instead."
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" "Report the trigger briefly in the final task update"
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" "When a user gives a new requirement, draft or update the task plan first."
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" 'read `docs/context/FRESH_REPO_BOOTSTRAP.md` before feature planning or implementation.'
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" "Use that file only for first-run bootstrap handling."
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" '`git 마무리해`'
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" 'bash scripts/land-task.sh'
  assert_file_contains "$TEMPLATE_DIR/docs/context/FRESH_REPO_BOOTSTRAP.md" 'run `bash scripts/init-project.sh` before feature planning or implementation.'
  assert_file_contains "$TEMPLATE_DIR/docs/context/FRESH_REPO_BOOTSTRAP.md" '"프로젝트 셋팅부터 하자"'
  assert_file_contains "$TEMPLATE_DIR/README.md" 'bash scripts/init-project.sh'
  assert_file_contains "$TEMPLATE_DIR/README.md" 'bash scripts/land-task.sh <task-id>'
  test -f "$TEMPLATE_DIR/scripts/land-task.sh" || fail "missing scripts/land-task.sh"
  assert_file_contains "$TEMPLATE_DIR/README.md" '"이 템플릿 막 export한 새 repo야. 셋업부터 해줘."'
  assert_file_contains "$TEMPLATE_DIR/README.md" '`AGENTS.md`: canonical workflow behavior and live process rules'
  test -f "$TEMPLATE_DIR/scripts/status-task.sh" || fail "missing scripts/status-task.sh"
  assert_file_contains "$TEMPLATE_DIR/README.md" 'Prefer `bash scripts/status-task.sh [task-id]` when you want a local status summary.'
  assert_file_contains "$TEMPLATE_DIR/README.md" 'Local task selection is `explicit task id` first, then `current task branch` when it maps to a live task.'
  assert_file_contains "$TEMPLATE_DIR/README.md" 'compatibility alias for `status-task.sh`, not as a persisted dashboard generator'
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" 'Prefer `bash scripts/status-task.sh [task-id]` when you want a local status summary.'
  assert_file_contains "$TEMPLATE_DIR/docs/context/RESUME_GUIDE.md" 'Run `bash scripts/status-task.sh [task-id]` when you want a local status summary'
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" '`docs/tasks/<task-id>.md` owns the request-local contract'
  assert_file_contains "$TEMPLATE_DIR/AGENTS.md" 'Local commands select the task in this order: explicit task id, then current task branch.'
  assert_file_contains "$TEMPLATE_DIR/docs/context/ARCHITECTURE.md" '`docs/context/CI_PROFILE.md` owns repo CI defaults and check inventory.'
  assert_file_contains "$TEMPLATE_DIR/docs/tasks/README.md" '# Task Directory Guidance'
  assert_file_contains "$TEMPLATE_DIR/docs/tasks/README.md" 'For the detailed behavioral rules behind those commands, use `AGENTS.md` instead of this file.'
  assert_file_contains "$TEMPLATE_DIR/docs/context/RESUME_GUIDE.md" 'canonical tracked task contract, task state, scope, and verification/review summaries'
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" "task_id:"
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" "CI_TASK_ID:"
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" "inputs.task_id || ''"
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" 'CI_HEAD_BRANCH: ${{ github.event_name == '\''pull_request'\'' && github.event.pull_request.head.ref || github.ref_name }}'
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" 'CI_DIFF_BASE: ${{ github.event_name == '\''pull_request'\'' && github.event.pull_request.base.sha || github.event.before }}'
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" 'CI_DIFF_HEAD: ${{ github.event_name == '\''pull_request'\'' && github.event.pull_request.head.sha || github.sha }}'
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" 'CI_PR_BODY: ${{ github.event_name == '\''pull_request'\'' && github.event.pull_request.body || '\'''\'' }}'
  assert_file_contains "$TEMPLATE_DIR/.github/workflows/ai-gate.yml" 'CI_TASK_ID: ${{ github.event_name == '\''workflow_dispatch'\'' && inputs.task_id || '\'''\'' }}'
  test -f "$TEMPLATE_DIR/scripts/export-stable-template.sh" || fail "missing scripts/export-stable-template.sh"
}

scenario_init_project_from_exported_bundle() {
  local task_file_count

  setup_exported_bundle_repo "init-project-from-exported-bundle"
  cd "$CURRENT_SMOKE_REPO"

  test ! -f .template-source-root || fail "exported bundle should not include the source marker"
  test ! -f scripts/export-stable-template.sh || fail "exported bundle should not include the export helper"
  test ! -f docs/tasks/migrate-stable-ai-template.md || fail "exported bundle should not include template task history"
  task_file_count="$(find docs/tasks -maxdepth 1 -type f | wc -l | tr -d ' ')"
  [[ "$task_file_count" == "2" ]] || fail "expected only README.md and _template.md before init"

  bash scripts/init-project.sh --base-branch develop >/dev/null

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "init-project should create a git repo"
  [[ "$(git branch --show-current)" == "develop" ]] || fail "init-project should use the requested bootstrap branch"

  assert_file_contains docs/context/PROJECT.md "project-name: Init Project From Exported Bundle"
  assert_file_contains docs/context/PROJECT.md "repo-slug: init-project-from-exported-bundle"
  assert_file_contains docs/context/PROJECT.md "platform=web, stack=custom"
  assert_file_contains docs/context/ARCHITECTURE.md "product entrypoints for the web app"
  assert_file_contains docs/context/CI_PROFILE.md "- platform: web"
  assert_file_contains docs/context/CI_PROFILE.md "- stack: custom"
  assert_file_contains docs/context/CI_PROFILE.md "- default-base-branch: develop"
  assert_file_contains docs/context/CI_PROFILE.md '`bash scripts/check-context.sh`'

  test ! -f docs/tasks/migrate-stable-ai-template.md || fail "template task history should be removed"
  test -f docs/tasks/project-bootstrap.md || fail "project-bootstrap task should exist"

  task_file_count="$(find docs/tasks -maxdepth 1 -type f | wc -l | tr -d ' ')"
  [[ "$task_file_count" == "3" ]] || fail "expected only README.md, _template.md, and project-bootstrap.md after init"

  assert_file_contains docs/tasks/project-bootstrap.md "# Task: project-bootstrap"
  assert_file_contains docs/tasks/project-bootstrap.md "repo-specific bootstrap context for Init Project From Exported Bundle"
  assert_file_contains docs/tasks/project-bootstrap.md '`bash scripts/check-task.sh project-bootstrap`'

  test ! -f .context/current.md || fail "init-project should not create .context/current.md"
  status_output="$(bash scripts/status-task.sh project-bootstrap)"
  printf '%s' "$status_output" | grep -Fq -- "- active-task: project-bootstrap" || fail "status-task should report the bootstrap task"
  printf '%s' "$status_output" | grep -Fq -- "- task-state: planning" || fail "status-task should report the bootstrap task state"
  printf '%s' "$status_output" | grep -Fq -- "- base-branch: develop" || fail "status-task should report the configured base branch"

  bash scripts/check-context.sh >/dev/null
  bash scripts/check-task.sh project-bootstrap >/dev/null
}

scenario_scope_and_approval() {
  setup_repo "scope-and-approval"
  cd "$CURRENT_SMOKE_REPO"

  printf 'preexisting dirty\n' > notes.txt
  expect_failure "bootstrap-task should reject a dirty new task start" bash scripts/bootstrap-task.sh scope-safety
  rm -f notes.txt
  bash scripts/bootstrap-task.sh scope-safety >/dev/null
  test ! -f .context/active_task || fail "bootstrap-task should not create .context/active_task"

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

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

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
  expect_failure "check-scope should fail for new unrelated files inside the active task" bash scripts/check-scope.sh scope-safety
  rm -f stray.txt

  bash scripts/run-task-checks.sh scope-safety >/dev/null
  bash scripts/review-scope.sh scope-safety --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh scope-safety --summary "quick review: narrow change and deterministic check" >/dev/null
  assert_file_contains docs/tasks/scope-safety.md "- state: review"
  printf '\n# review-fix\n' >> src/app.sh
  bash scripts/run-task-checks.sh scope-safety >/dev/null
  bash scripts/review-scope.sh scope-safety --summary "scope stayed inside src/app.sh after the review-stage fix" >/dev/null
  bash scripts/review-quality.sh scope-safety --summary "review-stage fix stayed in the same task and kept deterministic checks" >/dev/null
  bash scripts/complete-task.sh scope-safety "updated the approved app output" "create a task branch before publish if this task needs a PR" >/dev/null

  test ! -f .context/current.md || fail "complete-task should not create .context/current.md"
  grep -Eq 'verification-fingerprint: [0-9a-f]{64}$' docs/tasks/scope-safety.md || fail "verification should dual-write a tracked fingerprint"
  grep -Eq 'scope-review-fingerprint: [0-9a-f]{64}$' docs/tasks/scope-safety.md || fail "scope review should dual-write a tracked fingerprint"
  grep -Eq 'quality-review-fingerprint: [0-9a-f]{64}$' docs/tasks/scope-safety.md || fail "quality review should dual-write a tracked fingerprint"
  status_output="$(bash scripts/status-task.sh scope-safety)"
  printf '%s' "$status_output" | grep -Fq -- "- task-state: done" || fail "status-task should report done tasks"
  printf '%s' "$status_output" | grep -Fq -- "- verification-status: pass" || fail "status-task should report verification status"
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

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh main-commit-guard >/dev/null
  bash scripts/approve-task.sh main-commit-guard --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh main-commit-guard >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh

  git add src/app.sh docs/tasks/main-commit-guard.md
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
- The server check passes, wrapper-driven PR recovery injects Task-ID metadata when needed, and merge syncs local main cleanly.

## Verification Commands
- `bash tests/server-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

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
  expect_failure "standard quality review should require architecture review" \
    bash scripts/review-quality.sh publish-late-flow \
      --summary "reviewed reuse, hardcoding, tests, and request scope for the server change" \
      --reuse pass \
      --hardcoding pass \
      --tests pass \
      --request-scope pass
  bash scripts/review-quality.sh publish-late-flow \
    --summary "reviewed reuse, hardcoding, tests, and request scope for the server change" \
    --reuse pass \
    --hardcoding pass \
    --tests pass \
    --request-scope pass \
    --architecture pass >/dev/null
  bash scripts/complete-task.sh publish-late-flow \
    "updated the approved server output" \
    "create or switch to task/publish-late-flow, commit the approved diff, then publish the PR" >/dev/null

  CI_DIFF_BASE="1111111111111111111111111111111111111111" CI_DIFF_HEAD="2222222222222222222222222222222222222222" bash scripts/check-task.sh publish-late-flow >/dev/null

  git switch -c task/publish-late-flow >/dev/null
  expect_failure "open-task-pr should fail on a dirty task branch" bash scripts/open-task-pr.sh publish-late-flow

  git add src/server.sh docs/tasks/publish-late-flow.md
  git commit -qm "task(publish-late-flow): initial publish"

  PR_BODY_FILE="$(mktemp)"
  printf 'Loose notes only\n' > "$PR_BODY_FILE"
  gh pr create --base main --head task/publish-late-flow --body-file "$PR_BODY_FILE" >/dev/null
  rm -f "$PR_BODY_FILE"

  PR_NUMBER="$(gh pr view task/publish-late-flow --json number --jq '.number')"
  [[ -n "$PR_NUMBER" ]] || fail "expected PR number after initial publish"
  PR_BODY="$(gh pr view "$PR_NUMBER" --json body | jq -r '.body')"
  printf '%s\n' "$PR_BODY" | grep -Fq 'Loose notes only' || fail "expected seed PR body content before wrapper recovery"
  if printf '%s\n' "$PR_BODY" | grep -Fq 'Task-ID:'; then
    fail "expected seed PR body without Task-ID metadata"
  fi

  bash scripts/open-task-pr.sh publish-late-flow >/dev/null

  PR_BODY="$(gh pr view "$PR_NUMBER" --json body | jq -r '.body')"
  printf '%s\n' "$PR_BODY" | grep -Fq 'Task-ID: publish-late-flow' || fail "missing Task-ID metadata in repaired PR body"
  printf '%s\n' "$PR_BODY" | grep -Fq 'Loose notes only' || fail "expected wrapper to preserve existing PR body content"

  perl -0pi -e 's/- follow-up: .*/- follow-up: publish update documented after initial PR creation/' docs/tasks/publish-late-flow.md
  bash scripts/check-task.sh publish-late-flow >/dev/null
  git add docs/tasks/publish-late-flow.md
  git commit -qm "task(publish-late-flow): update mutable summary"
  rm -f .context/tasks/publish-late-flow/pr.env

  bash scripts/open-task-pr.sh publish-late-flow >/dev/null
  grep -Eq '^pr-edit:[0-9]+$' "$FAKE_GH_STATE_DIR/gh.log" || fail "expected PR updates to target a numeric PR id"

  rm -rf .context/tasks
  CI_EVENT_NAME="pull_request" CI_REF_NAME="4/merge" CI_HEAD_BRANCH="task/publish-late-flow" CI_PR_BODY="" CI_DIFF_BASE="origin/main" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh >/dev/null

  HEAD_SHA="$(gh pr view "$PR_NUMBER" --json headRefOid | jq -r '.headRefOid')"
  mark_check_success "$HEAD_SHA" "AI Gate"

  gh pr merge "$PR_NUMBER" --squash --delete-branch >/dev/null
  git switch main >/dev/null
  git fetch origin main >/dev/null
  git merge --ff-only origin/main >/dev/null
  git branch -d task/publish-late-flow >/dev/null 2>&1 || true

  [[ "$(git branch --show-current)" == "main" ]] || fail "expected manual merge flow to return to main"
  [[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] || fail "expected local main to sync with origin/main"
  assert_branch_absent "$CURRENT_SMOKE_REPO" "task/publish-late-flow"
  test ! -f .context/current.md || fail "manual merge flow should not recreate .context/current.md"
  status_output="$(bash scripts/status-task.sh)"
  printf '%s' "$status_output" | grep -Fq -- "- active-task: none" || fail "status-task should show no active task after merge cleanup"
}

scenario_land_task_shortcut() {
  local land_log
  local land_pid
  local pr_number=""
  local head_sha=""
  local attempt

  setup_repo "land-task-shortcut"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh git-finish-flow >/dev/null

  cat > docs/tasks/git-finish-flow.md <<'EOF'
# Task: git-finish-flow

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
- split-rationale: one server behavior change and its publish flow
- bundle-override-approved: no

## Goal
- Update the server output to `api=v2` and land the publish-ready task through the git finish shortcut.

## Non-goals
- Do not change the app output or bundle another feature.

## Requirements
- RQ-001: `src/server.sh` must emit `api=v2`.

## Implementation Plan
- Step 1: update `src/server.sh`.
- Step 2: verify and review the task.
- Step 3: use the landing shortcut to commit, publish, merge, sync, and clean up.

## Target Files
- `src/server.sh`
- `scripts/land-task.sh`

## Out of Scope
- `src/app.sh`, CI definitions, and unrelated workflow files remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing server shell script, verification command, and publish-late workflow scripts.
- config/constants to centralize: keep landing waits in the landing script environment variables.
- side effects to avoid: leaving the task branch behind or publishing before the task is done.

## Risk Controls
- sensitive areas touched: server output contract and publish automation.
- extra checks before merge: rerun the required AI Gate check on the latest PR head SHA.

## Acceptance
- The landing shortcut commits the approved diff, waits for AI Gate, merges the PR, syncs main, and deletes the task branch.

## Verification Commands
- `bash tests/server-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh git-finish-flow >/dev/null
  bash scripts/approve-task.sh git-finish-flow --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh git-finish-flow >/dev/null
  perl -0pi -e 's/api=v1/api=v2/' src/server.sh

  bash scripts/run-task-checks.sh git-finish-flow >/dev/null
  bash scripts/review-scope.sh git-finish-flow --summary "scope stayed inside src/server.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh git-finish-flow \
    --summary "reviewed the shortcut publish flow against the existing server change" \
    --reuse pass \
    --hardcoding pass \
    --tests pass \
    --request-scope pass \
    --architecture pass >/dev/null
  bash scripts/complete-task.sh git-finish-flow \
    "updated the approved server output and prepared the task for the landing shortcut" \
    "run bash scripts/land-task.sh git-finish-flow to publish and merge the task" >/dev/null

  land_log="$TMP_DIR/land-task-shortcut.log"
  LAND_TASK_CHECK_POLL_SECONDS=1 LAND_TASK_CHECK_TIMEOUT_SECONDS=30 \
    bash scripts/land-task.sh git-finish-flow >"$land_log" 2>&1 &
  land_pid=$!

  for attempt in $(seq 1 20); do
    pr_number="$(gh pr view task/git-finish-flow --json number --jq '.number' 2>/dev/null || true)"
    if [[ -n "$pr_number" ]]; then
      break
    fi
    sleep 1
  done

  [[ -n "$pr_number" ]] || {
    cat "$land_log" >&2 || true
    fail "expected the landing shortcut to create a PR"
  }

  head_sha="$(gh pr view "$pr_number" --json headRefOid | jq -r '.headRefOid')"
  [[ -n "$head_sha" && "$head_sha" != "null" ]] || fail "expected a PR head sha for the landing shortcut"
  mark_check_success "$head_sha" "AI Gate"

  wait "$land_pid" || {
    cat "$land_log" >&2 || true
    fail "land-task shortcut should succeed"
  }

  [[ "$(git branch --show-current)" == "main" ]] || fail "expected land-task shortcut to return to main"
  [[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] || fail "expected land-task shortcut to sync local main"
  assert_branch_absent "$CURRENT_SMOKE_REPO" "task/git-finish-flow"
  git -C "$CURRENT_SMOKE_REPO" show-ref --verify --quiet "refs/remotes/origin/task/git-finish-flow" && fail "expected remote task branch ref to be pruned"
  test ! -f .context/current.md || fail "land-task should not create .context/current.md"
  status_output="$(bash scripts/status-task.sh)"
  printf '%s' "$status_output" | grep -Fq -- "- active-task: none" || fail "status-task should show no active task after land-task"
  grep -Fq "pr-merge:$pr_number" "$FAKE_GH_STATE_DIR/gh.log" || fail "expected land-task shortcut to merge the PR"
}

scenario_land_task_without_pr_cache() {
  local land_log
  local land_pid
  local pr_number=""
  local head_sha=""

  setup_repo "land-task-without-pr-cache"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh land-without-pr-cache >/dev/null

  cat > docs/tasks/land-without-pr-cache.md <<'EOF'
# Task: land-without-pr-cache

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
- split-rationale: prove landing can recover an existing PR without local PR cache
- bundle-override-approved: no

## Goal
- Update the app output and land the already-published task even when `.context/tasks/<task-id>/pr.env` is absent.

## Non-goals
- Do not change server behavior or CI resolver logic.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.
- RQ-002: `land-task` must merge an already-open PR without requiring `pr.env`.

## Implementation Plan
- Step 1: update `src/app.sh`, verify, review, and mark the task done.
- Step 2: publish the task branch once.
- Step 3: delete `pr.env` and prove `land-task` still resolves and merges the PR.

## Target Files
- `src/app.sh`

## Out of Scope
- `src/server.sh`, merge policy changes, and unrelated workflow files.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script, smoke check, and landing flow.
- config/constants to centralize: keep landing waits in the landing script environment variables.
- side effects to avoid: treating the local PR cache as required state.

## Risk Controls
- sensitive areas touched: PR recovery during landing only.
- extra checks before merge: rerun the required AI Gate check on the latest PR head SHA.

## Acceptance
- `land-task` succeeds after `pr.env` is deleted and still merges the existing PR cleanly.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh land-without-pr-cache >/dev/null
  bash scripts/approve-task.sh land-without-pr-cache --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh land-without-pr-cache >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  bash scripts/run-task-checks.sh land-without-pr-cache >/dev/null
  bash scripts/review-scope.sh land-without-pr-cache --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh land-without-pr-cache --summary "quick review: narrow change and deterministic check" >/dev/null
  bash scripts/complete-task.sh land-without-pr-cache \
    "updated the approved app output and prepared the published task for landing" \
    "run bash scripts/land-task.sh land-without-pr-cache after the PR is ready" >/dev/null

  git switch -c task/land-without-pr-cache >/dev/null
  git add src/app.sh docs/tasks/land-without-pr-cache.md
  git commit -qm "task(land-without-pr-cache): initial publish"
  bash scripts/open-task-pr.sh land-without-pr-cache >/dev/null
  pr_number="$(gh pr view task/land-without-pr-cache --json number --jq '.number')"
  [[ -n "$pr_number" ]] || fail "expected a PR before landing without pr cache"

  rm -f .context/tasks/land-without-pr-cache/pr.env
  land_log="$TMP_DIR/land-task-without-pr-cache.log"
  LAND_TASK_CHECK_POLL_SECONDS=1 LAND_TASK_CHECK_TIMEOUT_SECONDS=30 \
    bash scripts/land-task.sh land-without-pr-cache >"$land_log" 2>&1 &
  land_pid=$!

  head_sha="$(gh pr view "$pr_number" --json headRefOid | jq -r '.headRefOid')"
  [[ -n "$head_sha" && "$head_sha" != "null" ]] || fail "expected a PR head sha before landing without pr cache"
  mark_check_success "$head_sha" "AI Gate"

  wait "$land_pid" || {
    cat "$land_log" >&2 || true
    fail "land-task should succeed without a local pr.env cache"
  }

  [[ "$(git branch --show-current)" == "main" ]] || fail "expected land-task without pr cache to return to main"
  [[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] || fail "expected land-task without pr cache to sync local main"
  assert_branch_absent "$CURRENT_SMOKE_REPO" "task/land-without-pr-cache"
  grep -Fq "pr-merge:$pr_number" "$FAKE_GH_STATE_DIR/gh.log" || fail "expected land-task without pr cache to merge the PR"
  rm -f .context/tasks/land-without-pr-cache/pr.env
  status_output="$(bash scripts/status-task.sh land-without-pr-cache)"
  printf '%s' "$status_output" | grep -Fq -- "- pr-status: none" || fail "status-task should surface missing PR cache after landing without pretending an open PR still exists"
  printf '%s' "$status_output" | grep -Fq -- "inspect remote PR history if needed, otherwise continue with the next task" || fail "status-task should stop recommending land-task when the publish branch is gone and PR status is unavailable"
}

scenario_land_task_skips_committed_deleted_files() {
  local land_log
  local land_pid
  local pr_number=""
  local head_sha=""

  setup_repo "land-task-committed-delete"
  cd "$CURRENT_SMOKE_REPO"

  mkdir -p docs/legacy
  printf 'obsolete content\n' > docs/legacy/obsolete.md
  git add docs/legacy/obsolete.md
  git commit -qm "seed: tracked obsolete file"
  git push origin main >/dev/null

  bash scripts/bootstrap-task.sh land-committed-delete >/dev/null

  cat > docs/tasks/land-committed-delete.md <<'EOF'
# Task: land-committed-delete

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: trivial
- updated-at-utc: 2026-04-21 00:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one app tweak plus one approved delete-only cleanup
- bundle-override-approved: no

## Goal
- Update the app output and land a publish-ready task whose branch already contains an approved tracked-file deletion.

## Non-goals
- Do not change server behavior or widen scope beyond the approved delete.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.
- RQ-002: `docs/legacy/obsolete.md` may be deleted as part of the same task.

## Implementation Plan
- Step 1: update `src/app.sh` and delete the approved legacy file.
- Step 2: verify, review, and mark the task done.
- Step 3: publish once, then prove `land-task` can merge without trying to restage the already-committed delete.

## Target Files
- `src/app.sh`
- `delete-only:docs/legacy/obsolete.md`

## Out of Scope
- `src/server.sh`, unrelated docs, and workflow policy changes remain unchanged.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script, smoke harness, and landing flow.
- config/constants to centralize: keep landing waits in the landing script environment variables.
- side effects to avoid: restaging already-committed deletes during landing.

## Risk Controls
- sensitive areas touched: landing automation path selection for deleted files only.
- extra checks before merge: rerun the required AI Gate check on the latest PR head SHA.

## Acceptance
- `land-task` lands the published task even when its committed diff already includes a tracked-file deletion and there are no new local changes to stage.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh land-committed-delete >/dev/null
  bash scripts/approve-task.sh land-committed-delete --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh land-committed-delete >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  rm -f docs/legacy/obsolete.md
  bash scripts/run-task-checks.sh land-committed-delete >/dev/null
  bash scripts/review-scope.sh land-committed-delete --summary "scope stayed inside src/app.sh, the approved delete-only file, and workflow internals" >/dev/null
  bash scripts/review-quality.sh land-committed-delete --summary "quick review: published delete-only diff should not be restaged during landing" >/dev/null
  bash scripts/complete-task.sh land-committed-delete \
    "updated the approved app output and removed the obsolete tracked file before landing" \
    "run bash scripts/land-task.sh land-committed-delete after the PR is ready" >/dev/null

  git switch -c task/land-committed-delete >/dev/null
  git add src/app.sh docs/legacy/obsolete.md docs/tasks/land-committed-delete.md
  git commit -qm "task(land-committed-delete): initial publish"
  bash scripts/open-task-pr.sh land-committed-delete >/dev/null
  pr_number="$(gh pr view task/land-committed-delete --json number --jq '.number')"
  [[ -n "$pr_number" ]] || fail "expected a PR before landing the committed delete scenario"

  land_log="$TMP_DIR/land-task-committed-delete.log"
  LAND_TASK_CHECK_POLL_SECONDS=1 LAND_TASK_CHECK_TIMEOUT_SECONDS=30 \
    bash scripts/land-task.sh land-committed-delete >"$land_log" 2>&1 &
  land_pid=$!

  head_sha="$(gh pr view "$pr_number" --json headRefOid | jq -r '.headRefOid')"
  [[ -n "$head_sha" && "$head_sha" != "null" ]] || fail "expected a PR head sha before landing the committed delete scenario"
  mark_check_success "$head_sha" "AI Gate"

  wait "$land_pid" || {
    cat "$land_log" >&2 || true
    fail "land-task should succeed when the published branch already contains a tracked-file delete"
  }

  [[ "$(git branch --show-current)" == "main" ]] || fail "expected committed delete landing to return to main"
  [[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] || fail "expected committed delete landing to sync local main"
  assert_branch_absent "$CURRENT_SMOKE_REPO" "task/land-committed-delete"
  test ! -f docs/legacy/obsolete.md || fail "expected the deleted tracked file to stay removed after landing"
  grep -Fq "pr-merge:$pr_number" "$FAKE_GH_STATE_DIR/gh.log" || fail "expected committed delete landing to merge the PR"
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

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

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

scenario_delete_only_scope() {
  setup_repo "delete-only-scope"
  cd "$CURRENT_SMOKE_REPO"

  mkdir -p docs/notes archive/old
  printf 'seed note\n' > docs/notes/seed.md
  printf 'legacy file\n' > archive/old/legacy.md
  git add docs/notes/seed.md archive/old/legacy.md
  git commit -qm "seed: tracked files for scope matching"

  bash scripts/bootstrap-task.sh delete-only-scope >/dev/null

  cat > docs/tasks/delete-only-scope.md <<'EOF'
# Task: delete-only-scope

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
- split-rationale: one docs cleanup request only
- bundle-override-approved: no

## Goal
- Allow a narrow docs cleanup to modify one notes prefix and delete legacy archive files without enumerating every nested delete.

## Non-goals
- Do not widen scope for unrelated source files.

## Requirements
- RQ-001: files under `docs/notes/` may be edited.
- RQ-002: files matching `archive/**` may be deleted only.

## Implementation Plan
- Step 1: edit one note under the approved prefix.
- Step 2: delete one tracked archive file and verify scope still passes.

## Target Files
- `docs/notes/`
- `delete-only:archive/**`

## Out of Scope
- `src/` files and non-delete changes under `archive/`.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the shared scope checker and target-file rules.
- config/constants to centralize: none
- side effects to avoid: allowing archive edits that are not deletions.

## Risk Controls
- sensitive areas touched: scope matching for prefix and delete-only rules.
- extra checks before merge: none

## Acceptance
- `check-scope` passes for the approved prefix edit plus delete-only cleanup and still fails for unrelated files.

## Verification Commands
- `bash tests/project-fast-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  perl -0pi -e 's/seed note/updated note/' docs/notes/seed.md
  rm -f archive/old/legacy.md

  bash scripts/check-task.sh delete-only-scope >/dev/null
  bash scripts/check-scope.sh delete-only-scope >/dev/null

  printf '#!/usr/bin/env bash\necho extra\n' > src/extra.sh
  expect_failure "check-scope should reject files outside prefix/delete-only rules" bash scripts/check-scope.sh delete-only-scope
}

scenario_task_supersession() {
  setup_repo "task-supersession"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh fetch-boundary >/dev/null

  cat > docs/tasks/fetch-boundary.md <<'EOF'
# Task: fetch-boundary

> Normal PR rule: one PR should map to one live task file.

## Status
- state: review
- owner: ai
- risk-level: standard
- updated-at-utc: 2026-04-12 00:00:00Z

## Approval
- approved-by: user
- approved-at-utc: 2026-04-12 00:00:00Z
- approval-note: approved fetch-boundary work

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one fetch-boundary change cluster
- bundle-override-approved: no

## Goal
- Keep source fetch behavior inside the approved adapter boundary.

## Non-goals
- Do not add semantic extraction or a second task flow here.

## Requirements
- RQ-001: keep the fetch behavior inside the approved adapter boundary.

## Implementation Plan
- Step 1: finish the approved fetch boundary work.

## Architecture Notes
- intended module boundaries: keep fetch logic in the adapter boundary.
- dependency direction: callers depend on the adapter, not on extraction details.
- extraction/refactor triggers in touched files: split extraction into a new task if the goal changes.

## Target Files
- `src/app.sh`

## Out of Scope
- semantic extraction and workflow redesign remain out of scope.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app script.
- config/constants to centralize: none
- side effects to avoid: avoid broadening the request into semantic extraction.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- The fetch-boundary diff is ready for completion unless the goal changes.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pass
- verification-note: verification passed; see .context/tasks/fetch-boundary/verification.log
- verification-at-utc: 2026-04-12 00:00:00Z

## Review Status
- scope-review-status: pass
- scope-review-note: scope stayed inside src/app.sh and workflow internals
- scope-review-at-utc: 2026-04-12 00:00:00Z
- quality-review-status: pass
- quality-review-note: fetch-boundary review passed
- quality-review-at-utc: 2026-04-12 00:00:00Z
- reuse-review: pass
- hardcoding-review: pass
- tests-review: pass
- request-scope-review: pass
- architecture-review: pass
- risk-controls-review: n/a

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/check-task.sh fetch-boundary >/dev/null
  bash scripts/bootstrap-task.sh semantic-extraction --supersedes fetch-boundary --reason "the approved direction changed from fetch-boundary completion to semantic extraction" >/dev/null

  assert_file_contains docs/tasks/fetch-boundary.md "- state: superseded"
  assert_file_contains docs/tasks/fetch-boundary.md "Continue in docs/tasks/semantic-extraction.md."
  assert_file_contains docs/tasks/fetch-boundary.md "Task superseded before completion because the approved direction changed from fetch-boundary completion to semantic extraction"
  bash scripts/check-task.sh fetch-boundary >/dev/null
  bash scripts/check-scope.sh semantic-extraction >/dev/null
  test ! -f .context/active_task || fail "replacement bootstrap should not recreate .context/active_task"
  status_output="$(bash scripts/status-task.sh semantic-extraction)"
  printf '%s' "$status_output" | grep -Fq -- "- active-task: semantic-extraction" || fail "status-task should reflect the replacement task when addressed explicitly"
}

scenario_ai_gate_command_dedupe() {
  local ai_gate_log
  local ai_gate_output

  setup_repo "ai-gate-command-dedupe"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh ai-gate-command-dedupe >/dev/null

  cat > tests/record-check.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
name="${1:?}"
mkdir -p .context
printf '%s\n' "$name" >> .context/ci-command-runs.log
EOF
  chmod +x tests/record-check.sh

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
- `bash tests/record-check.sh shared`

## High-Risk Checks
- `bash tests/record-check.sh shared`

## Full Project Checks
- `bash tests/record-check.sh shared`

## Notes
- The smoke repo uses a fake gh binary and local bare git remotes only.
EOF

  cat > docs/tasks/ai-gate-command-dedupe.md <<'EOF'
# Task: ai-gate-command-dedupe

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: high-risk
- updated-at-utc: 2026-04-07 00:00:00Z

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one narrow CI dedupe proof for repeated top-level commands
- bundle-override-approved: no

## Goal
- Update the app output and prove AI Gate dedupes repeated commands across verification and CI profile sections.

## Non-goals
- Do not change task detection, publish flow, or nested commands inside a single check.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.
- RQ-002: `bash tests/record-check.sh shared` appears in verification plus every CI profile section but must run once per AI Gate pass.

## Implementation Plan
- Step 1: update `src/app.sh`, add the shared marker check, and configure repeated CI profile commands.
- Step 2: complete the approved task and commit the in-scope diff.
- Step 3: run AI Gate with full project checks enabled and confirm duplicate skips.

## Architecture Notes
- intended module boundaries: keep app behavior in `src/app.sh`, supplemental project coverage in `docs/context/CI_PROFILE.md`, and the dedupe marker in a dedicated smoke-only check script.
- dependency direction: AI Gate should orchestrate task verification and supplemental project checks while the shared marker script observes execution only.
- extraction/refactor triggers in touched files: none for this narrow smoke fixture.

## Target Files
- `src/app.sh`
- `docs/context/CI_PROFILE.md`
- `tests/record-check.sh`

## Out of Scope
- PR metadata recovery and server behavior.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app check and smoke repo workflow scripts.
- config/constants to centralize: reuse the shared marker name `shared` across verification and project checks only.
- side effects to avoid: changing server output or adding unrelated workflow behavior.

## Risk Controls
- sensitive areas touched: AI Gate execution order and repeated project-check requests in the CI profile.
- extra checks before merge: rerun the task verification commands and rerun AI Gate with full project checks enabled.

## Acceptance
- AI Gate passes and the shared marker command records exactly one run even though verification and all project-check sections request it.

## Verification Commands
- `bash tests/app-check.sh`
- `bash tests/record-check.sh shared`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh ai-gate-command-dedupe >/dev/null
  bash scripts/approve-task.sh ai-gate-command-dedupe --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh ai-gate-command-dedupe >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh

  bash scripts/run-task-checks.sh ai-gate-command-dedupe >/dev/null
  bash scripts/review-scope.sh ai-gate-command-dedupe --summary "scope stayed inside src/app.sh, docs/context/CI_PROFILE.md, and tests/record-check.sh" >/dev/null
  bash scripts/review-quality.sh ai-gate-command-dedupe \
    --summary "reviewed the shared marker coverage and high-risk gate assertions" \
    --reuse pass \
    --hardcoding pass \
    --tests pass \
    --request-scope pass \
    --architecture pass \
    --risk-controls pass >/dev/null
  bash scripts/complete-task.sh ai-gate-command-dedupe \
    "proved AI Gate runs the shared marker command once per gate pass" \
    "publish from the task branch after confirming the dedupe log output" >/dev/null

  git switch -c task/ai-gate-command-dedupe >/dev/null
  git add src/app.sh docs/context/CI_PROFILE.md tests/record-check.sh docs/tasks/ai-gate-command-dedupe.md
  git commit -qm "task(ai-gate-command-dedupe): prove shared command dedupe"
  CHECK_SCOPE_MODE=ci bash scripts/check-scope.sh ai-gate-command-dedupe >/dev/null
  rm -f .context/tasks/ai-gate-command-dedupe/verification.receipt
  rm -f .context/tasks/ai-gate-command-dedupe/scope-review.receipt
  rm -f .context/tasks/ai-gate-command-dedupe/quality-review.receipt

  rm -f .context/ci-command-runs.log
  ai_gate_log="$(mktemp)"
  CI_EVENT_NAME="pull_request" \
    CI_REF_NAME="9/merge" \
    CI_HEAD_BRANCH="task/ai-gate-command-dedupe" \
    CI_PR_BODY="" \
    CI_DIFF_BASE="origin/main" \
    CI_DIFF_HEAD="HEAD" \
    CI_RUN_FULL_PROJECT_CHECKS="1" \
    bash scripts/ci/run-ai-gate.sh >"$ai_gate_log" 2>&1

  [[ "$(grep -c '^shared$' .context/ci-command-runs.log)" == "1" ]] || fail "expected shared dedupe command to run once"
  assert_file_contains "$ai_gate_log" "[RUN][verification] bash tests/record-check.sh shared"
  assert_file_contains "$ai_gate_log" "[SKIP][pr-fast] bash tests/record-check.sh shared (already ran in verification)"
  assert_file_contains "$ai_gate_log" "[SKIP][high-risk] bash tests/record-check.sh shared (already ran in verification)"
  assert_file_contains "$ai_gate_log" "[SKIP][full-project] bash tests/record-check.sh shared (already ran in verification)"
  assert_file_contains "$ai_gate_log" "[PASS] ai-gate"

  printf 'out of scope\n' > stray.txt
  git add stray.txt
  git commit -qm "chore: out-of-scope committed change"

  expect_failure "check-scope should reject out-of-scope committed files in ci mode" env CHECK_SCOPE_MODE=ci bash scripts/check-scope.sh ai-gate-command-dedupe
  if ai_gate_output="$(CI_EVENT_NAME="pull_request" CI_REF_NAME="9/merge" CI_HEAD_BRANCH="task/ai-gate-command-dedupe" CI_PR_BODY="" CI_DIFF_BASE="origin/main" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh 2>&1)"; then
    fail "ai-gate should reject committed diffs that invalidate freshness or scope"
  fi
  printf '%s' "$ai_gate_output" | grep -Eq '\[FAIL\] task|\[FAIL\] scope' || fail "ai-gate should fail through the shared freshness or scope validators"
}

scenario_ci_active_task_fallback() {
  local ai_gate_output

  setup_repo "ci-metadata-mismatch"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh ci-active-fallback >/dev/null

  cat > docs/tasks/ci-active-fallback.md <<'EOF'
# Task: ci-active-fallback

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
- Update the app output and prove CI no longer falls back to the active task when metadata sources are absent.

## Non-goals
- Do not depend on the local active task file for the follow-up CI rerun.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.

## Implementation Plan
- Step 1: update `src/app.sh` and complete the approved task.
- Step 2: make one in-scope follow-up commit without changing the task file.
- Step 3: prove CI fails closed without CI metadata and still passes with explicit `CI_TASK_ID`.

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
- side effects to avoid: relying on stale local runtime task pointers during CI.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- CI should fail when only `.context/active_task` could identify the task and should pass again when `CI_TASK_ID` is provided explicitly.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh ci-active-fallback >/dev/null
  bash scripts/approve-task.sh ci-active-fallback --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh ci-active-fallback >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  bash scripts/run-task-checks.sh ci-active-fallback >/dev/null
  bash scripts/review-scope.sh ci-active-fallback --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh ci-active-fallback --summary "quick review: narrow change and deterministic check" >/dev/null
  bash scripts/complete-task.sh ci-active-fallback "updated the approved app output" "publish from the task branch" >/dev/null

  git switch -c task/ci-active-fallback >/dev/null
  git add src/app.sh docs/tasks/ci-active-fallback.md
  git commit -qm "task(ci-active-fallback): initial publish"

  printf 'ci-active-fallback\n' > .context/active_task
  printf '\n- active fallback smoke note\n' >> docs/context/DECISIONS.md
  git add docs/context/DECISIONS.md
  git commit -qm "docs: keep the latest diff inside workflow internals"

  if ai_gate_output="$(env CI_PR_BODY="" CI_REF_NAME="" CI_HEAD_BRANCH="" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh 2>&1)"; then
    fail "ai-gate should not use .context/active_task in CI"
  fi
  printf '%s' "$ai_gate_output" | grep -Fq "could not resolve a task id from explicit Task-ID, PR body, branch name, or one changed task file" || fail "ai-gate should fail during task resolution when only .context/active_task is available"

  printf 'stale-active-task\n' > .context/active_task
  CI_TASK_ID="ci-active-fallback" CI_PR_BODY="" CI_REF_NAME="" CI_HEAD_BRANCH="" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh >/dev/null
  [[ "$(cat .context/active_task)" == "stale-active-task" ]] || fail "ai-gate should not rewrite .context/active_task"

  if ai_gate_output="$(env CI_TASK_ID="does-not-exist" CI_PR_BODY="" CI_REF_NAME="9/merge" CI_HEAD_BRANCH="task/ci-active-fallback" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh 2>&1)"; then
    fail "ai-gate should fail closed when an explicit CI_TASK_ID is invalid"
  fi
  printf '%s' "$ai_gate_output" | grep -Fq "explicit Task-ID does not match a live task file" || fail "ai-gate should report invalid explicit Task-ID overrides"
}

scenario_ci_pr_metadata_and_changed_task_file_resolvers() {
  setup_repo "ci-resolver-matrix"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh ci-resolver-matrix >/dev/null

  cat > docs/tasks/ci-resolver-matrix.md <<'EOF'
# Task: ci-resolver-matrix

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
- split-rationale: prove CI resolver compatibility paths stay valid
- bundle-override-approved: no

## Goal
- Prove AI Gate still resolves the task from PR metadata and from one changed live task file when branch metadata is unavailable.

## Non-goals
- Do not rely on `.context/active_task`.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.
- RQ-002: AI Gate must pass with PR body metadata only.
- RQ-003: AI Gate must pass with exactly one changed live task file and no metadata.

## Implementation Plan
- Step 1: complete a narrow app change and publish-ready task state.
- Step 2: prove PR body resolution with branch metadata removed.
- Step 3: prove changed-task-file resolution with PR and branch metadata removed.

## Target Files
- `src/app.sh`

## Out of Scope
- Server behavior and local runtime dashboards.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the app script and existing gate checks.
- config/constants to centralize: none
- side effects to avoid: hidden dependence on branch metadata during CI reruns.

## Risk Controls
- sensitive areas touched: CI task identity resolution only.
- extra checks before merge: none

## Acceptance
- AI Gate should pass when only PR body `Task-ID` is available and should pass when exactly one changed live task file identifies the task.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh ci-resolver-matrix >/dev/null
  bash scripts/approve-task.sh ci-resolver-matrix --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh ci-resolver-matrix >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  bash scripts/run-task-checks.sh ci-resolver-matrix >/dev/null
  bash scripts/review-scope.sh ci-resolver-matrix --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh ci-resolver-matrix --summary "quick review: narrow change and deterministic check" >/dev/null
  bash scripts/complete-task.sh ci-resolver-matrix "proved the documented AI Gate resolver compatibility paths" "publish from the task branch" >/dev/null

  git switch -c task/ci-resolver-matrix >/dev/null
  git add src/app.sh docs/tasks/ci-resolver-matrix.md
  git commit -qm "task(ci-resolver-matrix): initial publish"

  printf '\n- pr metadata resolver smoke\n' >> docs/context/DECISIONS.md
  git add docs/context/DECISIONS.md
  git commit -qm "docs: keep a workflow-internal follow-up diff"

  CI_PR_BODY=$'Task-ID: ci-resolver-matrix' CI_REF_NAME="" CI_HEAD_BRANCH="" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh >/dev/null

  perl -0pi -e 's/publish from the task branch/publish remains blocked on explicit checks/' docs/tasks/ci-resolver-matrix.md
  git add docs/tasks/ci-resolver-matrix.md
  git commit -qm "docs(ci-resolver-matrix): task-file-only follow-up"

  CI_PR_BODY="" CI_REF_NAME="" CI_HEAD_BRANCH="" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash scripts/ci/run-ai-gate.sh >/dev/null
}

scenario_ci_resolver_precedence_and_ambiguity() {
  local resolved_task
  local resolver_output

  setup_repo "ci-resolver-precedence"
  cd "$CURRENT_SMOKE_REPO"

  for task_id in resolver-explicit resolver-priority resolver-branch resolver-file resolver-file-a resolver-file-b; do
    printf '# Task: %s\n' "$task_id" > "docs/tasks/$task_id.md"
  done
  git add docs/tasks/resolver-explicit.md docs/tasks/resolver-priority.md docs/tasks/resolver-branch.md docs/tasks/resolver-file.md docs/tasks/resolver-file-a.md docs/tasks/resolver-file-b.md
  git commit -qm "docs: add resolver fixture tasks"

  resolved_task="$(CI_TASK_ID="resolver-explicit" CI_PR_BODY=$'Task-ID: resolver-priority' CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit')"
  [[ "$resolved_task" == "resolver-explicit" ]] || fail "explicit CI_TASK_ID should win over PR metadata and branch metadata"

  if resolver_output="$(CI_TASK_ID="../context/PROJECT" CI_PR_BODY="" CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "path-style explicit CI_TASK_ID values should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "explicit Task-ID does not match a live task file" || fail "invalid explicit CI_TASK_ID values should report a closed failure"

  resolved_task="$(CI_TASK_ID="" CI_PR_BODY=$'Task-ID: resolver-priority' CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit')"
  [[ "$resolved_task" == "resolver-priority" ]] || fail "PR body Task-ID should win over branch metadata"

  resolved_task="$(CI_TASK_ID="" CI_PR_BODY='This PR has no metadata block' CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit')"
  [[ "$resolved_task" == "resolver-branch" ]] || fail "branch metadata should be used when the PR body has no Task-ID metadata"

  if resolver_output="$(CI_TASK_ID="" CI_PR_BODY=$'Task-ID: does-not-exist' CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "invalid PR body Task-ID metadata should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "PR body Task-ID does not match a live task file" || fail "invalid PR body Task-ID should report a closed failure"

  if resolver_output="$(CI_TASK_ID="" CI_PR_BODY=$'Task-ID: ../context/PROJECT' CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "path-style PR body Task-ID values should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "PR body Task-ID does not match a live task file" || fail "invalid PR body Task-ID paths should report a closed failure"

  if resolver_output="$(CI_TASK_ID="" CI_PR_BODY=$'Task-ID: resolver-priority\nTask-ID: resolver-branch' CI_REF_NAME="" CI_HEAD_BRANCH="" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "duplicated PR body Task-ID metadata should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "PR body Task-ID metadata is malformed or ambiguous" || fail "duplicated PR body Task-ID metadata should report ambiguity"

  if resolver_output="$(CI_TASK_ID="" CI_PR_BODY=$'Task-ID: \n' CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "blank PR body Task-ID metadata should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "PR body Task-ID metadata is malformed or ambiguous" || fail "blank PR body Task-ID metadata should report malformed metadata"

  perl -0pi -e 's/# Task: resolver-file/# Task: resolver-file\n# single changed task file/' docs/tasks/resolver-file.md
  git add docs/tasks/resolver-file.md
  git commit -qm "docs: create single changed task file resolver diff"

  resolved_task="$(CI_TASK_ID="" CI_PR_BODY="" CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/resolver-branch" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit')"
  [[ "$resolved_task" == "resolver-branch" ]] || fail "branch metadata should win over changed-task-file fallback"

  if resolver_output="$(CI_TASK_ID="" CI_PR_BODY="" CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/does-not-exist" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "invalid branch-derived task ids should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "branch-derived task id does not match a live task file" || fail "invalid branch-derived task ids should report a closed failure"

  if resolver_output="$(CI_TASK_ID="" CI_PR_BODY="" CI_REF_NAME="13/merge" CI_HEAD_BRANCH="task/bad_id" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "malformed branch-derived task ids should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "branch-derived task id is malformed" || fail "malformed branch-derived task ids should report malformed metadata"

  resolved_task="$(CI_TASK_ID="" CI_PR_BODY="" CI_REF_NAME="" CI_HEAD_BRANCH="" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit')"
  [[ "$resolved_task" == "resolver-file" ]] || fail "one changed live task file should resolve the task when metadata is absent"

  perl -0pi -e 's/# Task: resolver-file-a/# Task: resolver-file-a\n# ambiguous changed task file a/' docs/tasks/resolver-file-a.md
  perl -0pi -e 's/# Task: resolver-file-b/# Task: resolver-file-b\n# ambiguous changed task file b/' docs/tasks/resolver-file-b.md
  git add docs/tasks/resolver-file-a.md docs/tasks/resolver-file-b.md
  git commit -qm "docs: create ambiguous changed task file diff"

  if resolver_output="$(CI_TASK_ID="" CI_PR_BODY="" CI_REF_NAME="" CI_HEAD_BRANCH="" CI_DIFF_BASE="HEAD~1" CI_DIFF_HEAD="HEAD" bash -c 'source scripts/ci/run-ai-gate.sh; detect_task_id_or_exit' 2>&1)"; then
    fail "ambiguous task identity should fail closed"
  fi
  printf '%s' "$resolver_output" | grep -Fq "could not resolve a task id from explicit Task-ID, PR body, branch name, or one changed task file" || fail "ambiguous resolver failures should report task-resolution failure"
}

scenario_status_task_surface() {
  local status_output

  setup_repo "status-task-surface"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh status-task-surface >/dev/null

  cat > docs/tasks/status-task-surface.md <<'EOF'
# Task: status-task-surface

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
- split-rationale: prove the status command covers the operator summary surface
- bundle-override-approved: no

## Goal
- Prove `scripts/status-task.sh` exposes enough local task status to replace persisted dashboard inspection.

## Non-goals
- Do not add a second persisted status file for this flow.

## Requirements
- RQ-001: `scripts/status-task.sh` must report active task, task state, next action, changed files, risk, verification log hint, and PR status.

## Implementation Plan
- Step 1: create an in-progress task with a failing verification run.
- Step 2: inspect the local status command output.

## Target Files
- `src/app.sh`

## Out of Scope
- Server behavior and CI resolver logic.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the app script and existing task checks.
- config/constants to centralize: none
- side effects to avoid: relying on any persisted dashboard file as the only status surface.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- The status command should show the failing verification path and available PR metadata from local state.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh status-task-surface >/dev/null
  bash scripts/approve-task.sh status-task-surface --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh status-task-surface >/dev/null
  perl -0pi -e 's/button-size=4/button-size=7/' src/app.sh
  expect_failure "run-task-checks should fail while app output is still wrong" bash scripts/run-task-checks.sh status-task-surface

  git switch -c task/status-task-surface >/dev/null
  git add src/app.sh docs/tasks/status-task-surface.md
  git commit -qm "task(status-task-surface): status command repro"

  PR_BODY_FILE="$(mktemp)"
  printf 'Task-ID: status-task-surface\n' > "$PR_BODY_FILE"
  gh pr create --base main --head task/status-task-surface --body-file "$PR_BODY_FILE" >/dev/null
  rm -f "$PR_BODY_FILE"
  status_output="$(bash scripts/status-task.sh)"
  printf '%s' "$status_output" | grep -Fq -- "- active-task: status-task-surface" || fail "status-task should derive the task from the current task branch"

  git switch -c scratch-status-view >/dev/null
  printf '\n- unrelated status branch note\n' >> docs/context/DECISIONS.md
  git add docs/context/DECISIONS.md
  git commit -qm "docs: unrelated status branch PR"

  PR_BODY_FILE="$(mktemp)"
  printf 'Task-ID: unrelated-status-branch\n' > "$PR_BODY_FILE"
  gh pr create --base main --head scratch-status-view --body-file "$PR_BODY_FILE" >/dev/null
  rm -f "$PR_BODY_FILE"

  rm -f .context/tasks/status-task-surface/pr.env

  status_output="$(bash scripts/status-task.sh status-task-surface)"
  printf '%s' "$status_output" | grep -Fq -- "- active-task: status-task-surface" || fail "status-task should report the active task"
  printf '%s' "$status_output" | grep -Fq -- "- task-state: in_progress" || fail "status-task should report the task state"
  printf '%s' "$status_output" | grep -Fq -- "- risk-level: trivial" || fail "status-task should report the risk level"
  printf '%s' "$status_output" | grep -Fq -- ".context/tasks/status-task-surface/verification.log" || fail "status-task should report the verification log hint"
  printf '%s' "$status_output" | grep -Fq -- "- pr-status: open" || fail "status-task should report PR status"
  printf '%s' "$status_output" | grep -Fq -- "- pr-number: 1" || fail "status-task should report PR number"
  printf '%s' "$status_output" | grep -Fq -- "- pr-url: https://example.test/pr/1" || fail "status-task should report PR url"
  printf '%s' "$status_output" | grep -Fq -- '- `src/app.sh`' || fail "status-task should report changed files"
  printf '%s' "$status_output" | grep -Fq -- "bash scripts/run-task-checks.sh status-task-surface" || fail "status-task should report the next action"

  bash scripts/bootstrap-task.sh unpublished-status-task >/dev/null
  unpublished_status_output="$(bash scripts/status-task.sh unpublished-status-task)"
  printf '%s' "$unpublished_status_output" | grep -Fq -- "- pr-status: none" || fail "status-task should not borrow an unrelated current-branch PR for unpublished tasks"

  cat > docs/tasks/unpublished-status-task.md <<'EOF'
# Task: unpublished-status-task

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
- split-rationale: prove status-task distinguishes unpublished local done work from already-published branch cleanup
- bundle-override-approved: no

## Goal
- Surface the correct next action for a done task whose local changes are ready to publish but have not been committed on a task branch yet.

## Non-goals
- Do not publish the PR or merge the task.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.
- RQ-002: `status-task` must not tell the operator to inspect remote PR history when the task is only locally completed and still unpublished.

## Implementation Plan
- Step 1: update `src/app.sh`.
- Step 2: complete the task locally without creating the task branch.
- Step 3: prove `status-task` points to branch creation and publish as the next action.

## Target Files
- `src/app.sh`

## Out of Scope
- PR publication, merge automation, and unrelated workflow files.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script and smoke check.
- config/constants to centralize: none
- side effects to avoid: confusing unpublished local completion with a deleted publish branch.

## Risk Controls
- sensitive areas touched: done-state local publish guidance only.
- extra checks before merge: none

## Acceptance
- `status-task` reports that publish has not started yet and points to task branch creation plus PR publish when the task is done locally but still unpublished.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh unpublished-status-task >/dev/null
  bash scripts/approve-task.sh unpublished-status-task --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh unpublished-status-task >/dev/null
  perl -0pi -e 's/button-size=7/button-size=8/' src/app.sh
  bash scripts/run-task-checks.sh unpublished-status-task >/dev/null
  bash scripts/review-scope.sh unpublished-status-task --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh unpublished-status-task --summary "quality review passed for the unpublished local done-state status surface" --reuse pass --hardcoding pass --tests pass --request-scope pass --architecture pass >/dev/null
  bash scripts/complete-task.sh unpublished-status-task \
    "updated the app output and prepared the task for first publish" \
    "create task/unpublished-status-task, commit the approved files, and run bash scripts/open-task-pr.sh unpublished-status-task" >/dev/null

  done_unpublished_status_output="$(bash scripts/status-task.sh unpublished-status-task)"
  printf '%s' "$done_unpublished_status_output" | grep -Fq -- "- next-action: create task/unpublished-status-task, commit the approved files, and run bash scripts/open-task-pr.sh unpublished-status-task" || fail "status-task should point unpublished local done work to branch creation and publish"
  printf '%s' "$done_unpublished_status_output" | grep -Fq -- "- pr-status: none" || fail "status-task should still report no PR for unpublished local done work"
}

scenario_source_repo_init_guard() {
  expect_failure "init-project should reject the template source repo" bash "$TEMPLATE_DIR/scripts/init-project.sh"
}

scenario_refresh_current_wrapper_alias() {
  setup_repo "active-task-only-source-of-truth"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh active-task-only >/dev/null
  wrapper_output="$(bash scripts/refresh-current.sh active-task-only)"
  status_output="$(bash scripts/status-task.sh active-task-only)"
  [[ "$wrapper_output" == "$status_output" ]] || fail "refresh-current should be a compatibility alias for status-task"
  test ! -f .context/current.md || fail "refresh-current should not create .context/current.md"
}

scenario_review_publish_requires_fresh_review_state() {
  local publish_output

  setup_repo "review-publish-requires-fresh-review-state"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh review-publish-freshness >/dev/null

  cat > docs/tasks/review-publish-freshness.md <<'EOF'
# Task: review-publish-freshness

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
- split-rationale: prove review-stage publish still rejects stale freshness
- bundle-override-approved: no

## Goal
- Publish a review-stage task only when verification is fresh and no recorded review has already failed.

## Non-goals
- Do not complete the task or test merge flows.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.
- RQ-002: `open-task-pr` must reject review-stage tasks whose quality review is recorded as `fail`.
- RQ-003: `open-task-pr` must reject invalid review-stage quality status values.
- RQ-004: `open-task-pr` must reject review-stage drift after verification and reviews have passed.

## Implementation Plan
- Step 1: update `src/app.sh`.
- Step 2: record a failing quality review and prove publish is blocked.
- Step 3: record a passing quality review, prove malformed status values are blocked, then prove a later drift still blocks publish.

## Target Files
- `src/app.sh`

## Out of Scope
- `src/server.sh`, done-state publish rules, and merge automation.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script and smoke check.
- config/constants to centralize: none
- side effects to avoid: publishing stale review state from the task branch.

## Risk Controls
- sensitive areas touched: review-stage publish enforcement only.
- extra checks before merge: none

## Acceptance
- `open-task-pr` fails when quality review is recorded as failed, fails again when review status values are missing or malformed, and fails again when the diff changes after review-stage verification and review passes.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh review-publish-freshness >/dev/null
  bash scripts/approve-task.sh review-publish-freshness --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh review-publish-freshness >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  bash scripts/run-task-checks.sh review-publish-freshness >/dev/null
  bash scripts/review-scope.sh review-publish-freshness --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null

  git switch -c task/review-publish-freshness >/dev/null
  git add src/app.sh docs/tasks/review-publish-freshness.md
  git commit -qm "task(review-publish-freshness): verification and scope review passed"

  if bash scripts/review-quality.sh \
    review-publish-freshness \
    --summary "quality review found unresolved issues" \
    --reuse fail \
    --hardcoding fail \
    --tests fail \
    --request-scope fail \
    --architecture fail >/dev/null 2>&1; then
    fail "review-quality should fail when review dimensions fail for a standard-risk task"
  fi

  git add docs/tasks/review-publish-freshness.md
  git commit -qm "task(review-publish-freshness): record failed quality review"

  if publish_output="$(bash scripts/open-task-pr.sh review-publish-freshness 2>&1)"; then
    fail "open-task-pr should reject failed review-stage quality review"
  fi
  printf '%s' "$publish_output" | grep -Fq "[FAIL] quality-review" || fail "failed quality review should block review-stage publish"

  bash scripts/review-quality.sh \
    review-publish-freshness \
    --summary "quality review passed after resolving the review findings" \
    --reuse pass \
    --hardcoding pass \
    --tests pass \
    --request-scope pass \
    --architecture pass >/dev/null

  git add docs/tasks/review-publish-freshness.md
  git commit -qm "task(review-publish-freshness): record passing quality review"

  perl -0pi -e 's/\n- quality-review-status: pass//' docs/tasks/review-publish-freshness.md
  git add docs/tasks/review-publish-freshness.md
  git commit -qm "task(review-publish-freshness): remove quality review status"

  if publish_output="$(bash scripts/open-task-pr.sh review-publish-freshness 2>&1)"; then
    fail "open-task-pr should reject missing review-stage quality review status"
  fi
  printf '%s' "$publish_output" | grep -Fq "[FAIL] quality-review" || fail "missing quality review status should block review-stage publish"
  printf '%s' "$publish_output" | grep -Fq "requires quality-review-status to be present" || fail "missing review status should be reported explicitly"

  perl -0pi -e 's/\n- quality-review-note:/\n- quality-review-status: pass\n- quality-review-note:/' docs/tasks/review-publish-freshness.md
  git add docs/tasks/review-publish-freshness.md
  git commit -qm "task(review-publish-freshness): restore missing quality review status"

  perl -0pi -e 's/quality-review-status: pass/quality-review-status: blocked/' docs/tasks/review-publish-freshness.md
  git add docs/tasks/review-publish-freshness.md
  git commit -qm "task(review-publish-freshness): record invalid quality review status"

  if publish_output="$(bash scripts/open-task-pr.sh review-publish-freshness 2>&1)"; then
    fail "open-task-pr should reject invalid review-stage quality review status values"
  fi
  printf '%s' "$publish_output" | grep -Fq "[FAIL] quality-review" || fail "invalid quality review status should block review-stage publish"
  printf '%s' "$publish_output" | grep -Fq "invalid quality-review-status=blocked" || fail "invalid review status should be reported explicitly"

  perl -0pi -e 's/quality-review-status: blocked/quality-review-status: pass/' docs/tasks/review-publish-freshness.md
  git add docs/tasks/review-publish-freshness.md
  git commit -qm "task(review-publish-freshness): restore valid quality review status"

  perl -0pi -e 's/button-size=8/button-size=9/' src/app.sh
  git add src/app.sh
  git commit -qm "task(review-publish-freshness): drift after review"

  if publish_output="$(bash scripts/open-task-pr.sh review-publish-freshness 2>&1)"; then
    fail "open-task-pr should reject stale review-stage freshness"
  fi
  printf '%s' "$publish_output" | grep -Fq "[FAIL] verification" || fail "review-stage drift should fail through verification freshness first"
  printf '%s' "$publish_output" | grep -Fq "tracked freshness is stale" || fail "review-stage drift should report stale tracked freshness"
}

scenario_done_publish_requires_tracked_freshness() {
  local verification_fingerprint
  local scope_fingerprint
  local quality_fingerprint

  setup_repo "done-publish-requires-tracked-freshness"
  cd "$CURRENT_SMOKE_REPO"

  bash scripts/bootstrap-task.sh stale-publish >/dev/null

  cat > docs/tasks/stale-publish.md <<'EOF'
# Task: stale-publish

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
- split-rationale: one narrow app output change
- bundle-override-approved: no

## Goal
- Update the app output to `button-size=8`.

## Non-goals
- Do not change server behavior or publish policy.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.

## Implementation Plan
- Step 1: update `src/app.sh`.
- Step 2: verify, review, and mark the task done.

## Target Files
- `src/app.sh`

## Out of Scope
- `src/server.sh` and unrelated workflow files.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script and smoke check.
- config/constants to centralize: none
- side effects to avoid: publishing stale task state after done.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- Fresh tracked review state should publish without receipt files, legacy receipt-only task docs should still publish, and drift after done must still block publish.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh stale-publish >/dev/null
  bash scripts/approve-task.sh stale-publish --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh stale-publish >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  bash scripts/run-task-checks.sh stale-publish >/dev/null
  bash scripts/review-scope.sh stale-publish --summary "scope stayed inside src/app.sh and workflow internals" >/dev/null
  bash scripts/review-quality.sh stale-publish --summary "quick review: narrow change and deterministic check" >/dev/null
  bash scripts/complete-task.sh stale-publish "updated the approved app output" "land the task" >/dev/null
  test ! -f .context/current.md || fail "complete-task should not create .context/current.md in done-task flows"
  verification_fingerprint="$(grep -E '^- verification-fingerprint: ' docs/tasks/stale-publish.md | sed 's/^- verification-fingerprint: //')"
  scope_fingerprint="$(grep -E '^- scope-review-fingerprint: ' docs/tasks/stale-publish.md | sed 's/^- scope-review-fingerprint: //')"
  quality_fingerprint="$(grep -E '^- quality-review-fingerprint: ' docs/tasks/stale-publish.md | sed 's/^- quality-review-fingerprint: //')"
  [[ "$verification_fingerprint" =~ ^[0-9a-f]{64}$ ]] || fail "verification fingerprint should be recorded on done tasks"
  [[ "$scope_fingerprint" =~ ^[0-9a-f]{64}$ ]] || fail "scope review fingerprint should be recorded on done tasks"
  [[ "$quality_fingerprint" =~ ^[0-9a-f]{64}$ ]] || fail "quality review fingerprint should be recorded on done tasks"

  perl -0pi -e 's/\n- verification-fingerprint: [^\n]*//; s/\n- scope-review-fingerprint: [^\n]*//; s/\n- quality-review-fingerprint: [^\n]*//' docs/tasks/stale-publish.md

  git switch -c task/stale-publish >/dev/null
  git add src/app.sh docs/tasks/stale-publish.md
  git commit -qm "task(stale-publish): legacy receipt-only publish-ready state"
  bash scripts/open-task-pr.sh stale-publish >/dev/null

  perl -0pi -e 's/(verification-at-utc: [^\n]*)/$1\n- verification-fingerprint: '"$verification_fingerprint"'/' docs/tasks/stale-publish.md
  perl -0pi -e 's/(scope-review-at-utc: [^\n]*)/$1\n- scope-review-fingerprint: '"$scope_fingerprint"'/' docs/tasks/stale-publish.md
  perl -0pi -e 's/(quality-review-at-utc: [^\n]*)/$1\n- quality-review-fingerprint: '"$quality_fingerprint"'/' docs/tasks/stale-publish.md
  git add docs/tasks/stale-publish.md
  git commit -qm "docs(stale-publish): restore tracked freshness fields"
  rm -f .context/tasks/stale-publish/verification.receipt
  rm -f .context/tasks/stale-publish/scope-review.receipt
  rm -f .context/tasks/stale-publish/quality-review.receipt
  bash scripts/open-task-pr.sh stale-publish >/dev/null

  perl -0pi -e 's/button-size=8/button-size=9/' src/app.sh
  git add src/app.sh
  git commit -qm "task(stale-publish): drift after done"

  expect_failure "open-task-pr should reject stale tracked freshness after done" bash scripts/open-task-pr.sh stale-publish
  expect_failure "land-task should reject stale tracked freshness after done" bash scripts/land-task.sh stale-publish
}

scenario_publish_late_without_origin_guard() {
  setup_repo "publish-late-without-origin-guard"
  cd "$CURRENT_SMOKE_REPO"

  git remote remove origin
  bash scripts/bootstrap-task.sh local-main-guard >/dev/null

  cat > docs/tasks/local-main-guard.md <<'EOF'
# Task: local-main-guard

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
- split-rationale: one narrow app output change
- bundle-override-approved: no

## Goal
- Update the app output to `button-size=8`.

## Non-goals
- Do not change server behavior or publish flow.

## Requirements
- RQ-001: `src/app.sh` must emit `button-size=8`.

## Implementation Plan
- Step 1: update `src/app.sh`.
- Step 2: prove publish-late still blocks main-branch commits without origin.

## Target Files
- `src/app.sh`

## Out of Scope
- `src/server.sh` and remote-only publish flows.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse the existing app shell script and smoke check.
- config/constants to centralize: none
- side effects to avoid: allowing committed task work on the base branch when no remote exists.

## Risk Controls
- sensitive areas touched: local publish-late protection without origin.
- extra checks before merge: none

## Acceptance
- Verification must fail when the task commit is made directly on the base branch without origin.

## Verification Commands
- `bash tests/app-check.sh`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/submit-task-plan.sh local-main-guard >/dev/null
  bash scripts/approve-task.sh local-main-guard --by "user" --note "approved" >/dev/null
  bash scripts/start-task.sh local-main-guard >/dev/null
  perl -0pi -e 's/button-size=4/button-size=8/' src/app.sh
  git add src/app.sh docs/tasks/local-main-guard.md
  git commit -qm "task(local-main-guard): incorrect base branch commit"

  expect_failure "run-task-checks should reject base-branch commits without origin" bash scripts/run-task-checks.sh local-main-guard
}

scenario_git_pr_defaults_and_overrides() {
  setup_repo "git-pr-defaults-and-overrides"
  cd "$CURRENT_SMOKE_REPO"

  git branch develop >/dev/null
  git push origin develop >/dev/null
  git branch release >/dev/null
  git push origin release >/dev/null

  bash scripts/bootstrap-task.sh git-pr-defaults >/dev/null
  perl -0pi -e 's/default-base-branch: main/default-base-branch: develop/' docs/context/CI_PROFILE.md
  perl -0pi -e 's/default-branch-strategy: publish-late/default-branch-strategy: early-branch/' docs/context/CI_PROFILE.md

  cat > docs/tasks/git-pr-defaults.md <<'EOF'
# Task: git-pr-defaults

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
- split-rationale: verify CI profile Git/PR defaults and task overrides
- bundle-override-approved: no

## Goal
- Prove task Git/PR fields inherit from CI profile by default and can still override when needed.

## Non-goals
- Do not publish a PR or change product behavior.

## Requirements
- RQ-001: `check-task` must pass when the task leaves Git/PR fields at fallback values.
- RQ-002: `status-task` must show CI profile defaults until a task override is set.

## Implementation Plan
- Step 1: validate CI profile fallback behavior.
- Step 2: set a task override and validate that it wins.

## Target Files
- `docs/context/CI_PROFILE.md`

## Out of Scope
- Product source changes and PR publication.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse CI profile defaults and status-task output.
- config/constants to centralize: keep Git/PR defaults in CI profile unless a task override is truly needed.
- side effects to avoid: hiding the override surface from the task contract.

## Risk Controls
- sensitive areas touched: task Git/PR resolution rules only.
- extra checks before merge: none

## Acceptance
- The status output first shows `develop` plus `early-branch`, then shows `release` plus `publish-late` after the task override.

## Verification Commands
- `bash scripts/check-task.sh git-pr-defaults`

## Verification Status
- verification-status: pending
- verification-note: pending
- verification-at-utc: pending

## Review Status
- scope-review-status: pending
- scope-review-note: pending
- scope-review-at-utc: pending
- quality-review-status: pending
- quality-review-note: pending
- quality-review-at-utc: pending
- reuse-review: pending
- hardcoding-review: pending
- tests-review: pending
- request-scope-review: pending
- architecture-review: pending
- risk-controls-review: pending

## Git / PR
- base-branch: pending
- branch-strategy: pending

## Completion
- summary: pending
- follow-up: pending
EOF

  bash scripts/check-task.sh git-pr-defaults >/dev/null
  status_output="$(bash scripts/status-task.sh git-pr-defaults)"
  printf '%s' "$status_output" | grep -Fq -- "- base-branch: develop" || fail "status-task should use CI profile defaults for base branch"
  printf '%s' "$status_output" | grep -Fq -- "- branch-strategy: early-branch" || fail "status-task should use CI profile defaults for branch strategy"

  perl -0pi -e 's/base-branch: pending/base-branch: release/' docs/tasks/git-pr-defaults.md
  perl -0pi -e 's/branch-strategy: pending/branch-strategy: publish-late/' docs/tasks/git-pr-defaults.md

  bash scripts/check-task.sh git-pr-defaults >/dev/null
  status_output="$(bash scripts/status-task.sh git-pr-defaults)"
  printf '%s' "$status_output" | grep -Fq -- "- base-branch: release" || fail "status-task should prefer task-level base-branch overrides"
  printf '%s' "$status_output" | grep -Fq -- "- branch-strategy: publish-late" || fail "status-task should prefer task-level branch-strategy overrides"

  perl -0pi -e 's/branch-strategy: publish-late/branch-strategy: pbulish-late/' docs/tasks/git-pr-defaults.md
  expect_failure "check-task should reject malformed branch-strategy values instead of silently falling back" bash scripts/check-task.sh git-pr-defaults
}

setup_fake_gh
assert_split_guidance_present

scenario_source_repo_init_guard
scenario_init_project_from_exported_bundle
scenario_scope_and_approval
scenario_publish_late_commit_rejection
scenario_publish_and_merge
scenario_land_task_shortcut
scenario_land_task_without_pr_cache
scenario_land_task_skips_committed_deleted_files
scenario_intake_validation
scenario_delete_only_scope
scenario_task_supersession
scenario_ai_gate_command_dedupe
scenario_refresh_current_wrapper_alias
scenario_review_publish_requires_fresh_review_state
scenario_done_publish_requires_tracked_freshness
scenario_publish_late_without_origin_guard
scenario_git_pr_defaults_and_overrides
scenario_ci_active_task_fallback
scenario_ci_pr_metadata_and_changed_task_file_resolvers
scenario_ci_resolver_precedence_and_ambiguity
scenario_status_task_surface

echo "[PASS] smoke"
