#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/init-project.sh [options]

Options:
  --project-name <name>      Human-readable project name
  --repo-slug <slug>         Repository slug used in docs/context/PROJECT.md
  --primary-users <text>     Primary users or maintainers for the repo
  --platform <type>          Forwarded to scripts/setup-ci-profile.sh
  --stack <framework>        Forwarded to scripts/setup-ci-profile.sh
  --base-branch <name>       Local base branch to use for bootstrap (default: main)
  --task-id <task-id>        Bootstrap task id to create (default: project-bootstrap)
  --interactive              Prompt for missing values instead of using inferred defaults
  --force                    Overwrite an already customized repo bootstrap state
  -h, --help                 Show this help text

Examples:
  bash scripts/init-project.sh
  bash scripts/init-project.sh --project-name "Acme App" --platform web --stack nextjs

This script is meant to run once in a brand new repository created by copying
an exported stable template bundle. It rewrites the repo identity docs,
regenerates the CI profile, creates a bootstrap task, and initializes git on
the chosen base branch when needed.
When no explicit values are provided, it infers sensible defaults from the
repository directory name so an AI agent can run it without stopping for input.
EOF
}

slugify() {
  printf '%s' "${1:-}" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

display_name_from_slug() {
  printf '%s' "${1:-}" |
    sed -E 's/[-_]+/ /g; s/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//' |
    awk '{
      for (i = 1; i <= NF; i++) {
        $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2))
      }
      print
    }'
}

prompt_with_default() {
  local prompt="$1"
  local default_value="$2"
  local answer

  if [[ -n "$default_value" ]]; then
    printf '%s [%s]: ' "$prompt" "$default_value" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi

  read -r answer
  answer="$(trim "$answer")"
  if [[ -n "$answer" ]]; then
    printf '%s' "$answer"
    return 0
  fi

  printf '%s' "$default_value"
}

require_safe_repo() {
  if [[ -f "$ROOT_DIR/.template-source-root" ]]; then
    echo "[ERROR] init-project.sh must run inside a new repo copied from an exported template bundle, not in the template source repo." >&2
    exit 1
  fi
}

ensure_rewrite_is_safe() {
  local current_slug=""
  local file
  local task_id

  if [[ -f "$ROOT_DIR/docs/context/PROJECT.md" ]]; then
    current_slug="$(section_key_value "$ROOT_DIR/docs/context/PROJECT.md" "## Identity" "repo-slug")"
  fi

  if [[ -n "$current_slug" && "$current_slug" != "context+multiagentdev" && "$current_slug" != "context+MultiAgentDev" && "$FORCE" -ne 1 ]]; then
    echo "[ERROR] PROJECT.md already looks customized for this repo. Re-run with --force if you really want to overwrite it." >&2
    exit 1
  fi

  if [[ -d "$TASKS_DIR" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      task_id="$(basename "$file" .md)"
      case "$task_id" in
        README|_template|"$BOOTSTRAP_TASK_ID")
          continue
          ;;
      esac
      if [[ "$FORCE" -ne 1 ]]; then
        echo "[ERROR] found existing task file docs/tasks/$task_id.md. Re-run with --force only if you intend to replace existing project task history." >&2
        exit 1
      fi
    done < <(find "$TASKS_DIR" -maxdepth 1 -type f -name '*.md' | sort)
  fi
}

ensure_git_repo() {
  local current_branch=""

  if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
      current_branch="$(git -C "$ROOT_DIR" symbolic-ref --short HEAD 2>/dev/null || true)"
      if [[ "$current_branch" != "$BASE_BRANCH" ]]; then
        git -C "$ROOT_DIR" symbolic-ref HEAD "refs/heads/$BASE_BRANCH"
      fi
    fi
    GIT_ACTION="kept existing git repository"
    return 0
  fi

  git -C "$ROOT_DIR" init -q
  git -C "$ROOT_DIR" symbolic-ref HEAD "refs/heads/$BASE_BRANCH"
  GIT_ACTION="initialized local git repository on $BASE_BRANCH"
}

write_project_context() {
  mkdir -p "$ROOT_DIR/docs/context"

  cat > "$ROOT_DIR/docs/context/PROJECT.md" <<EOF
# Project Context

## Identity
- project-name: $PROJECT_NAME
- repo-slug: $REPO_SLUG
- primary-users: $PRIMARY_USERS

## Product Goal
- Use this repository to build and evolve $PROJECT_NAME through task-scoped AI-assisted product work.
- Initial delivery assumptions: platform=$PROJECT_PLATFORM, stack=$PROJECT_STACK.

## Constraints
- Keep runtime task state under \`.context/\` and out of git.
- Treat this repo as a fresh product repo, not as the template source repository.
- Keep bootstrap changes focused on repo setup, workflow context, and CI defaults before feature delivery starts.

## Quality Bar
- New sessions should resume from repo-specific context rather than copied template task history.
- Git, CI, and workflow defaults should be explicit enough to start work without broad prompt expansion.
- Replace first-pass defaults with real project boundaries and checks as the product surface becomes clearer.

## Critical Flows
- Finish the initial \`$BOOTSTRAP_TASK_ID\` setup task before feature work begins.
- Map one live request to one task file and one PR flow after bootstrap.
- Refine CI commands and architecture notes whenever the real codebase makes the defaults stale.
EOF
}

write_architecture_context() {
  mkdir -p "$ROOT_DIR/docs/context"

  cat > "$ROOT_DIR/docs/context/ARCHITECTURE.md" <<EOF
# Architecture

## System Map
- entry/application: product entrypoints for the $PROJECT_PLATFORM app plus workflow scripts in \`scripts/\`
- domain/feature: feature modules that hold business rules for $PROJECT_NAME
- infrastructure/integration: storage, network, third-party adapters, and local workflow state under \`.context/\`
- shared: reusable utilities, shared UI/components, and test helpers

## Module Boundaries
- Keep product entrypoints thin and move business rules into feature or domain modules.
- Keep infrastructure and external integration code separate from domain logic.
- Workflow scripts own task state, verification evidence, freshness tracking, and PR automation; they should not become product runtime dependencies.
- Context docs own durable repo guidance, while task files own request-local scope and verification.

## Validator Boundaries
- \`scripts/check-task.sh\` owns task-contract validation.
- \`scripts/check-scope.sh\` owns scope validation for the current diff.
- \`scripts/ci/run-ai-gate.sh\` orchestrates those shared validators in CI and should not carry second copies of task-schema rules.

## Product Code Guardrails
- Prefer small feature modules over broad mixed files.
- Keep request handlers, views, or CLI entrypoints separate from domain rules.
- Keep IO and third-party integration concerns behind explicit adapters.
- Add shared abstractions only when at least two concrete callers need the same behavior.

## Dependency Rules
- allowed: product entrypoints may call domain modules and explicit adapters; workflow scripts may inspect docs, git state, and local \`.context/\`
- forbidden: domain logic depending directly on workflow scripts, and copied template history being treated as live product state

## Placement Rules
- new business logic: place it in the product source tree for this repo, not in workflow scripts
- new IO or adapter code: place it beside the relevant product integration or under \`scripts/\` when it is workflow-only
- new shared abstractions: place them in narrow shared modules near the callers that reuse them; only workflow helpers belong in \`scripts/_lib.sh\`

## Refactor Triggers
- Extract a new module when a touched file starts carrying more than one change reason.
- Separate bootstrap workflow edits from product feature edits if a task starts mixing them.
- Record follow-up cleanup in the task file when scope pressure forces a temporary compromise.
EOF
}

prune_template_task_history() {
  local file
  local base_name

  mkdir -p "$TASKS_DIR"

  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    base_name="$(basename "$file")"
    case "$base_name" in
      README.md|_template.md)
        continue
        ;;
    esac
    rm -f "$file"
  done < <(find "$TASKS_DIR" -maxdepth 1 -type f -name '*.md' | sort)
}

write_bootstrap_task() {
  local now
  now="$(utc_now)"

  cat > "$(task_file "$BOOTSTRAP_TASK_ID")" <<EOF
# Task: $BOOTSTRAP_TASK_ID

> Normal PR rule: one PR should map to one live task file.

## Status
- state: planning
- owner: ai
- risk-level: standard
- updated-at-utc: $now

## Approval
- approved-by: pending
- approved-at-utc: pending
- approval-note: pending

## Intake
- user-visible-change-clusters: 1
- split-decision: single-task
- split-rationale: one initial repo bootstrap cluster that replaces copied template context with repo-specific setup
- bundle-override-approved: no

## Goal
- Replace copied template identity and task history with repo-specific bootstrap context for $PROJECT_NAME.

## Non-goals
- Do not implement product features, roadmap ideas, or broad refactors during bootstrap.

## Requirements
- RQ-001: \`docs/context/PROJECT.md\` must describe $PROJECT_NAME instead of the template source repo.
- RQ-002: \`docs/context/ARCHITECTURE.md\` and \`docs/context/CI_PROFILE.md\` must provide usable first-pass defaults for platform=$PROJECT_PLATFORM and stack=$PROJECT_STACK.
- RQ-003: copied template task history must be removed so new sessions only see \`$BOOTSTRAP_TASK_ID\` as the live task.
- RQ-004: the repository must be ready to continue from a local git repo on base branch \`$BASE_BRANCH\`.

## Implementation Plan
- Step 1: confirm the repo identity, architecture notes, and CI profile generated during init.
- Step 2: refine any bootstrap defaults that are still too generic for the actual project.
- Step 3: approve the bootstrap task and complete any remaining repo setup before feature work starts.

## Architecture Notes
- intended module boundaries: keep workflow scripts responsible for task automation and keep product logic in the repo's real source tree.
- dependency direction: product entrypoints depend on domain logic and adapters; workflow docs and scripts remain outside product runtime paths.
- extraction/refactor triggers in touched files: split bootstrap-only docs or setup helpers before mixing them with feature implementation work.

## Target Files
- \`docs/context/PROJECT.md\`
- \`docs/context/ARCHITECTURE.md\`
- \`docs/context/CI_PROFILE.md\`
- \`docs/tasks/\`

## Out of Scope
- product feature code, deployment setup, and remote GitHub provisioning remain outside this bootstrap task.

## Scope Guardrails
- unrelated changes allowed: no
- incidental refactors allowed: no

## Reuse And Constraints
- existing abstractions to reuse: reuse \`scripts/setup-ci-profile.sh\` and the existing task lifecycle scripts.
- config/constants to centralize: keep branch and PR policy in \`docs/context/CI_PROFILE.md\`.
- side effects to avoid: avoid widening bootstrap into feature implementation or product architecture commitments that have not been discussed yet.

## Risk Controls
- sensitive areas touched: none
- extra checks before merge: none

## Acceptance
- New sessions resume from repo-specific context, and bootstrap can continue from \`$BOOTSTRAP_TASK_ID\` without copied template task noise.

## Verification Commands
- \`bash scripts/check-context.sh\`
- \`bash scripts/check-task.sh $BOOTSTRAP_TASK_ID\`

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
- architecture-review: pending
- risk-controls-review: pending

## Git / PR
- base-branch: pending
- branch-strategy: pending

## Completion
- summary: pending
- follow-up: pending
EOF
}

PROJECT_NAME=""
REPO_SLUG=""
PRIMARY_USERS=""
PLATFORM=""
STACK=""
BASE_BRANCH="main"
BOOTSTRAP_TASK_ID="project-bootstrap"
FORCE=0
INTERACTIVE=0
GIT_ACTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)
      PROJECT_NAME="$(trim "${2:-}")"
      shift 2
      ;;
    --repo-slug)
      REPO_SLUG="$(trim "${2:-}")"
      shift 2
      ;;
    --primary-users)
      PRIMARY_USERS="$(trim "${2:-}")"
      shift 2
      ;;
    --platform)
      PLATFORM="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --stack)
      STACK="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --base-branch)
      BASE_BRANCH="$(trim "${2:-}")"
      shift 2
      ;;
    --task-id)
      BOOTSTRAP_TASK_ID="$(trim "${2:-}")"
      shift 2
      ;;
    --interactive)
      INTERACTIVE=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_safe_repo

default_repo_slug="$(slugify "$(basename "$ROOT_DIR")")"
default_project_name="$(display_name_from_slug "$default_repo_slug")"
if [[ -z "$default_project_name" ]]; then
  default_project_name="$(basename "$ROOT_DIR")"
fi
if [[ -z "$PROJECT_NAME" ]]; then
  if [[ "$INTERACTIVE" -eq 1 ]]; then
    PROJECT_NAME="$(prompt_with_default "Project name" "$default_project_name")"
  else
    PROJECT_NAME="$default_project_name"
  fi
fi
if [[ -z "$REPO_SLUG" ]]; then
  if [[ "$INTERACTIVE" -eq 1 ]]; then
    REPO_SLUG="$(prompt_with_default "Repo slug" "$default_repo_slug")"
  else
    REPO_SLUG="$default_repo_slug"
  fi
fi
if [[ -z "$PRIMARY_USERS" ]]; then
  if [[ "$INTERACTIVE" -eq 1 ]]; then
    PRIMARY_USERS="$(prompt_with_default "Primary users" "developers and product collaborators")"
  else
    PRIMARY_USERS="developers and product collaborators"
  fi
fi

BOOTSTRAP_TASK_ID="$(slugify "$BOOTSTRAP_TASK_ID")"
BASE_BRANCH="$(trim "$BASE_BRANCH")"
PROJECT_NAME="$(trim "$PROJECT_NAME")"
REPO_SLUG="$(slugify "$REPO_SLUG")"
PRIMARY_USERS="$(trim "$PRIMARY_USERS")"

[[ -n "$PROJECT_NAME" ]] || {
  echo "[ERROR] project name is required" >&2
  exit 1
}
[[ -n "$REPO_SLUG" ]] || {
  echo "[ERROR] repo slug is required" >&2
  exit 1
}
[[ -n "$PRIMARY_USERS" ]] || {
  echo "[ERROR] primary users is required" >&2
  exit 1
}
[[ -n "$BASE_BRANCH" ]] || {
  echo "[ERROR] base branch is required" >&2
  exit 1
}
[[ -n "$BOOTSTRAP_TASK_ID" ]] || {
  echo "[ERROR] task id is required" >&2
  exit 1
}

ensure_rewrite_is_safe
ensure_git_repo
bash "$ROOT_DIR/scripts/bootstrap-task.sh" "$BOOTSTRAP_TASK_ID" >/dev/null

setup_ci_args=(--force --non-interactive)
if [[ -n "$PLATFORM" ]]; then
  setup_ci_args+=(--platform "$PLATFORM")
fi
if [[ -n "$STACK" ]]; then
  setup_ci_args+=(--stack "$STACK")
fi
setup_ci_args+=(--base-branch "$BASE_BRANCH")

bash "$ROOT_DIR/scripts/setup-ci-profile.sh" "${setup_ci_args[@]}" >/dev/null

PROJECT_PLATFORM="$(section_key_value "$(ci_profile_file)" "## Project Profile" "platform")"
PROJECT_STACK="$(section_key_value "$(ci_profile_file)" "## Project Profile" "stack")"

write_project_context
write_architecture_context
prune_template_task_history
write_bootstrap_task

bash "$ROOT_DIR/scripts/check-context.sh" >/dev/null
bash "$ROOT_DIR/scripts/check-task.sh" "$BOOTSTRAP_TASK_ID" >/dev/null

echo "[PASS] init-project"
echo " - project-name=$PROJECT_NAME"
echo " - repo-slug=$REPO_SLUG"
echo " - platform=$PROJECT_PLATFORM"
echo " - stack=$PROJECT_STACK"
echo " - bootstrap-task=$BOOTSTRAP_TASK_ID"
echo " - git=$GIT_ACTION"
