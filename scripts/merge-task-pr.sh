#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"

TASK_FILE="$(task_file "$TASK_ID")"
BASE_BRANCH="$(base_branch_from_task "$TASK_ID")"
PUBLISH_BRANCH="$(task_branch_name "$TASK_ID")"
MERGE_METHOD="$(merge_method_from_ci_profile)"
[[ -z "$MERGE_METHOD" ]] && MERGE_METHOD="squash"

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
[[ "$(task_state "$TASK_ID")" == "done" ]] || {
  echo "[FAIL] merge-task-pr"
  echo " - task must be in state done before merge"
  exit 1
}
ensure_clean_worktree || {
  echo "[FAIL] merge-task-pr"
  echo " - merge requires a clean worktree"
  exit 1
}

PR_NUMBER="$(resolve_pr_number_for_head_branch "$PUBLISH_BRANCH")"
if [[ -z "$PR_NUMBER" ]]; then
  echo "[FAIL] merge-task-pr"
  echo " - could not resolve an open PR for branch $PUBLISH_BRANCH"
  exit 1
fi

PR_JSON="$(gh pr view "$PR_NUMBER" --json number,isOpen,baseRefName,headRefName,headRefOid,body,url)"
PR_OPEN="$(printf '%s' "$PR_JSON" | jq -r '.isOpen')"
PR_BASE="$(printf '%s' "$PR_JSON" | jq -r '.baseRefName')"
PR_HEAD="$(printf '%s' "$PR_JSON" | jq -r '.headRefName')"
PR_HEAD_SHA="$(printf '%s' "$PR_JSON" | jq -r '.headRefOid')"
PR_BODY="$(printf '%s' "$PR_JSON" | jq -r '.body')"

[[ "$PR_OPEN" == "true" ]] || {
  echo "[FAIL] merge-task-pr"
  echo " - PR is not open"
  exit 1
}
[[ "$PR_BASE" == "$BASE_BRANCH" ]] || {
  echo "[FAIL] merge-task-pr"
  echo " - PR base branch does not match the task"
  exit 1
}
[[ "$PR_HEAD" == "$PUBLISH_BRANCH" ]] || {
  echo "[FAIL] merge-task-pr"
  echo " - PR head branch does not match the task branch"
  exit 1
}
[[ "$(printf '%s\n' "$PR_BODY" | extract_task_id_from_text)" == "$TASK_ID" ]] || {
  echo "[FAIL] merge-task-pr"
  echo " - PR body Task-ID does not match the task"
  exit 1
}

REQUIRED_CHECKS=()
while IFS= read -r check_name; do
  [[ -n "$check_name" ]] || continue
  REQUIRED_CHECKS+=("$check_name")
done < <(resolve_required_checks "$BASE_BRANCH")

if [[ ${#REQUIRED_CHECKS[@]} -eq 0 ]]; then
  echo "[FAIL] merge-task-pr"
  echo " - no required checks resolved for base branch $BASE_BRANCH"
  exit 1
fi

REPO_PATH="$(github_api_repo_path)"
for CHECK in "${REQUIRED_CHECKS[@]}"; do
  gh api "$REPO_PATH/commits/$PR_HEAD_SHA/check-runs" \
    | jq -e --arg check "$CHECK" 'any(.check_runs[]?; .name == $check and .status == "completed" and .conclusion == "success")' >/dev/null || {
      echo "[FAIL] merge-task-pr"
      echo " - required check is not green on the latest PR head SHA"
      echo " - check=$CHECK"
      exit 1
    }
done

case "$MERGE_METHOD" in
  squash)
    gh pr merge "$PR_NUMBER" --squash --delete-branch
    ;;
  merge)
    gh pr merge "$PR_NUMBER" --merge --delete-branch
    ;;
  rebase)
    gh pr merge "$PR_NUMBER" --rebase --delete-branch
    ;;
  *)
    echo "[FAIL] merge-task-pr"
    echo " - unsupported merge method: $MERGE_METHOD"
    exit 1
    ;;
esac

restore_current_snapshot_file
git -C "$ROOT_DIR" switch "$BASE_BRANCH"
git -C "$ROOT_DIR" fetch origin "$BASE_BRANCH"
git -C "$ROOT_DIR" merge --ff-only "origin/$BASE_BRANCH"

git -C "$ROOT_DIR" branch -d "$PUBLISH_BRANCH" 2>/dev/null || true
git -C "$ROOT_DIR" push origin --delete "$PUBLISH_BRANCH" 2>/dev/null || true

rm -f "$(pr_state_file "$TASK_ID")"
if [[ "$(active_task_value)" == "$TASK_ID" ]]; then
  rm -f "$ACTIVE_TASK_FILE"
fi

bash "$ROOT_DIR/scripts/refresh-current.sh" >/dev/null

echo "[PASS] merge-task-pr"
echo " - task=$TASK_ID"
