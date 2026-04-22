#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/land-task.sh [task-id] [--message "<commit message>"]

Environment:
  LAND_TASK_CHECK_TIMEOUT_SECONDS   Max seconds to wait for required checks (default: 1800)
  LAND_TASK_CHECK_POLL_SECONDS      Poll interval while waiting for checks (default: 10)

This command is for publish-ready tasks. It stages approved task-owned changes,
creates the task commit on the task branch if needed, opens or updates the PR,
waits for required checks, merges the PR, syncs the local base branch, deletes
the local task branch, and syncs the local base branch.
EOF
}

TASK_ID_INPUT=""
COMMIT_MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message)
      COMMIT_MESSAGE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$TASK_ID_INPUT" ]]; then
        usage >&2
        exit 1
      fi
      TASK_ID_INPUT="$1"
      shift
      ;;
  esac
done

TASK_ID="$(resolve_task_id_or_exit "$TASK_ID_INPUT")"
TASK_FILE="$(task_file "$TASK_ID")"
BASE_BRANCH="$(base_branch_from_task "$TASK_ID")"
EXPECTED_BRANCH="$(task_branch_name "$TASK_ID")"
CHECK_TIMEOUT_SECONDS="${LAND_TASK_CHECK_TIMEOUT_SECONDS:-1800}"
CHECK_POLL_SECONDS="${LAND_TASK_CHECK_POLL_SECONDS:-10}"
PR_NUMBER=""

sanitize_line() {
  printf '%s' "${1:-}" |
    tr '\n' ' ' |
    sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//; s/[.]$//'
}

fail_land() {
  echo "[FAIL] land-task"
  echo " - $1"
  exit 1
}

local_branch_exists() {
  git -C "$ROOT_DIR" show-ref --verify --quiet "refs/heads/$1"
}

remote_tracking_branch_exists() {
  git -C "$ROOT_DIR" show-ref --verify --quiet "refs/remotes/origin/$1"
}

default_commit_message() {
  local summary=""
  local goal=""
  local subject=""

  summary="$(section_key_value "$TASK_FILE" "## Completion" "summary")"
  if ! placeholder_like "$summary"; then
    subject="$(sanitize_line "$summary")"
  fi

  if [[ -z "$subject" ]]; then
    goal="$(section_bullet_values "$TASK_FILE" "## Goal" | head -n 1)"
    subject="$(sanitize_line "$goal")"
  fi

  if [[ -z "$subject" ]]; then
    subject="complete task"
  fi

  printf 'task(%s): %s' "$TASK_ID" "$subject"
}

stageable_changed_files() {
  local relative_path

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    case "$relative_path" in
      .context/*)
        continue
        ;;
    esac
    printf '%s\n' "$relative_path"
  done < <(effective_changed_files "$TASK_ID")
}

stage_task_changes() {
  local files=()
  local relative_path

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    files+=("$relative_path")
  done < <(stageable_changed_files)

  if [[ ${#files[@]} -gt 0 ]]; then
    git -C "$ROOT_DIR" add -- "${files[@]}"
  fi
}

merge_flag() {
  local merge_method

  merge_method="$(lower "$(section_key_value "$(ci_profile_file)" "## Git / PR Policy" "merge-method")")"
  case "$merge_method" in
    merge)
      printf '%s' "--merge"
      ;;
    rebase)
      printf '%s' "--rebase"
      ;;
    *)
      printf '%s' "--squash"
      ;;
  esac
}

switch_to_task_branch() {
  local current_branch

  current_branch="$(current_branch_name)"
  if [[ "$current_branch" == "$EXPECTED_BRANCH" ]]; then
    return 0
  fi

  if [[ "$current_branch" != "$BASE_BRANCH" ]]; then
    fail_land "current branch must be $BASE_BRANCH or $EXPECTED_BRANCH before landing"
  fi

  if local_branch_exists "$EXPECTED_BRANCH"; then
    git -C "$ROOT_DIR" switch "$EXPECTED_BRANCH" >/dev/null
    return 0
  fi

  if remote_tracking_branch_exists "$EXPECTED_BRANCH"; then
    git -C "$ROOT_DIR" switch -c "$EXPECTED_BRANCH" --track "origin/$EXPECTED_BRANCH" >/dev/null
    return 0
  fi

  git -C "$ROOT_DIR" switch -c "$EXPECTED_BRANCH" >/dev/null
}

required_checks_pass_for_sha() {
  local head_sha="$1"
  local checks_json="$2"
  local required_check="$3"
  local status
  local conclusion

  status="$(printf '%s' "$checks_json" | jq -r --arg name "$required_check" '[.check_runs[]? | select(.name == $name) | .status] | last // ""')"
  conclusion="$(printf '%s' "$checks_json" | jq -r --arg name "$required_check" '[.check_runs[]? | select(.name == $name) | .conclusion] | last // ""')"

  if [[ -z "$status" ]]; then
    return 1
  fi

  if [[ "$status" != "completed" ]]; then
    return 1
  fi

  if [[ "$conclusion" != "success" ]]; then
    fail_land "required check '$required_check' finished with conclusion '$conclusion' on $head_sha"
  fi

  return 0
}

wait_for_required_checks() {
  local required_checks=()
  local required_check
  local pr_json
  local pr_state
  local head_sha
  local checks_json
  local pending_count
  local deadline

  while IFS= read -r required_check; do
    [[ -n "$required_check" ]] || continue
    required_checks+=("$required_check")
  done < <(resolve_required_checks "$BASE_BRANCH" | sed '/^$/d' | sort -u)

  if [[ ${#required_checks[@]} -eq 0 ]]; then
    return 0
  fi

  deadline=$((SECONDS + CHECK_TIMEOUT_SECONDS))
  while :; do
    pr_json="$(gh pr view "$PR_NUMBER" --json state,headRefOid,baseRefName,url)"
    pr_state="$(printf '%s' "$pr_json" | jq -r '.state')"
    head_sha="$(printf '%s' "$pr_json" | jq -r '.headRefOid')"

    if [[ "$pr_state" != "OPEN" ]]; then
      fail_land "PR #$PR_NUMBER is no longer open while waiting for required checks"
    fi

    checks_json="$(gh api "$(github_api_repo_path)/commits/$head_sha/check-runs")"
    pending_count=0

    for required_check in "${required_checks[@]}"; do
      if ! required_checks_pass_for_sha "$head_sha" "$checks_json" "$required_check"; then
        pending_count=$((pending_count + 1))
      fi
    done

    if [[ "$pending_count" -eq 0 ]]; then
      return 0
    fi

    if (( SECONDS >= deadline )); then
      fail_land "timed out waiting for required checks on PR #$PR_NUMBER"
    fi

    sleep "$CHECK_POLL_SECONDS"
  done
}

bash "$ROOT_DIR/scripts/check-context.sh" >/dev/null
bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_task_state_in "$TASK_ID" done
ensure_publish_late_base_branch_safe "$TASK_ID" "fail-on-behind"

switch_to_task_branch
ensure_done_task_fresh_for_publish "$TASK_ID"
bash "$ROOT_DIR/scripts/check-scope.sh" "$TASK_ID" >/dev/null
stage_task_changes

if ! git -C "$ROOT_DIR" diff --cached --quiet --ignore-submodules -- .; then
  if [[ -z "$COMMIT_MESSAGE" ]]; then
    COMMIT_MESSAGE="$(default_commit_message)"
  fi
  git -C "$ROOT_DIR" commit -m "$COMMIT_MESSAGE" >/dev/null
fi

ensure_clean_worktree || fail_land "publish requires a clean worktree after staging task-owned changes"

bash "$ROOT_DIR/scripts/open-task-pr.sh" "$TASK_ID" >/dev/null
PR_NUMBER="$(printf '%s\n' "$(resolve_pr_snapshot_for_task "$TASK_ID" "$EXPECTED_BRANCH")" | sed -n '2p')"
if [[ -z "$PR_NUMBER" ]]; then
  fail_land "could not resolve a PR number after publish"
fi

wait_for_required_checks

gh pr merge "$PR_NUMBER" "$(merge_flag)" --delete-branch >/dev/null

if [[ "$(current_branch_name)" != "$BASE_BRANCH" ]]; then
  git -C "$ROOT_DIR" switch "$BASE_BRANCH" >/dev/null
fi

git -C "$ROOT_DIR" fetch --prune origin >/dev/null
git -C "$ROOT_DIR" merge --ff-only "origin/$BASE_BRANCH" >/dev/null
git -C "$ROOT_DIR" branch -d "$EXPECTED_BRANCH" >/dev/null 2>&1 || true

echo "[PASS] land-task"
echo " - task=$TASK_ID"
echo " - pr=$PR_NUMBER"
echo " - branch=$EXPECTED_BRANCH"
