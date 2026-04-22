#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"
shift || true

DRAFT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)
      DRAFT=1
      shift
      ;;
    *)
      echo "Usage: bash scripts/open-task-pr.sh <task-id> [--draft]" >&2
      exit 1
      ;;
  esac
done

TASK_FILE="$(task_file "$TASK_ID")"
BASE_BRANCH="$(base_branch_from_task "$TASK_ID")"
CURRENT_BRANCH="$(current_branch_name)"
EXPECTED_BRANCH="$(task_branch_name "$TASK_ID")"
TASK_STATE="$(task_state "$TASK_ID")"

strip_task_metadata_block() {
  awk '
    $0 == "<!-- task-metadata:start -->" { skip = 1; next }
    $0 == "<!-- task-metadata:end -->" { skip = 0; next }
    skip { next }
    { print }
  '
}

write_default_pr_body() {
  {
    render_pr_metadata_block "$TASK_ID" "$BASE_BRANCH"
    echo
    echo "## Goal"
    awk '/^## Goal/{flag=1;next}/^## /&&flag{exit}flag' "$TASK_FILE"
    echo
    echo "## Acceptance"
    awk '/^## Acceptance/{flag=1;next}/^## /&&flag{exit}flag' "$TASK_FILE"
  } > "$BODY_FILE"
}

write_recovered_pr_body() {
  local existing_body="$1"
  local stripped_body

  stripped_body="$(printf '%s\n' "$existing_body" | strip_task_metadata_block | sed '1{/^$/d;}')"
  if [[ -z "$(trim "$stripped_body")" ]]; then
    write_default_pr_body
    return 0
  fi

  {
    render_pr_metadata_block "$TASK_ID" "$BASE_BRANCH"
    echo
    printf '%s\n' "$stripped_body"
  } > "$BODY_FILE"
}

bash "$ROOT_DIR/scripts/check-task.sh" "$TASK_ID" >/dev/null
ensure_clean_worktree || {
  echo "[FAIL] open-task-pr"
  echo " - publish requires a clean worktree"
  exit 1
}

case "$TASK_STATE" in
  review|done)
    ;;
  in_progress)
    if [[ "$DRAFT" != "1" ]]; then
      echo "[FAIL] open-task-pr"
      echo " - use --draft while the task is still in progress"
      exit 1
    fi
    ;;
  *)
    echo "[FAIL] open-task-pr"
    echo " - task is not publishable in the current state"
    exit 1
    ;;
esac

if [[ "$TASK_STATE" == "review" ]]; then
  ensure_review_task_fresh_for_publish "$TASK_ID"
fi

if [[ "$TASK_STATE" == "done" ]]; then
  ensure_done_task_fresh_for_publish "$TASK_ID"
fi

if [[ "$CURRENT_BRANCH" == "$BASE_BRANCH" ]]; then
  echo "[FAIL] open-task-pr"
  echo " - publish must run from the task branch, not the base branch"
  exit 1
fi

if [[ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "[FAIL] open-task-pr"
  echo " - current branch does not match the task branch policy"
  echo " - current=$CURRENT_BRANCH"
  echo " - expected=$EXPECTED_BRANCH"
  exit 1
fi

ensure_origin_base_ref_available "$BASE_BRANCH"
read -r BEHIND AHEAD < <(ahead_behind_against_origin_base "$BASE_BRANCH")

if [[ "$AHEAD" -eq 0 ]]; then
  echo "[FAIL] open-task-pr"
  echo " - no committed diff to publish against origin/$BASE_BRANCH"
  exit 1
fi

if [[ "$BEHIND" -gt 0 ]]; then
  echo "[FAIL] open-task-pr"
  echo " - branch is behind origin/$BASE_BRANCH; sync before publish"
  exit 1
fi

git -C "$ROOT_DIR" push -u origin "$CURRENT_BRANCH"

PR_NUMBER="$(resolve_pr_number_for_head_branch "$CURRENT_BRANCH")"
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT
if [[ -n "$PR_NUMBER" ]]; then
  EXISTING_BODY="$(gh pr view "$PR_NUMBER" --json body | jq -r '.body')"
  write_recovered_pr_body "$EXISTING_BODY"
  gh pr edit "$PR_NUMBER" --body-file "$BODY_FILE"
else
  write_default_pr_body
  if [[ "$DRAFT" == "1" ]]; then
    gh pr create --base "$BASE_BRANCH" --head "$CURRENT_BRANCH" --fill --draft --body-file "$BODY_FILE"
  else
    gh pr create --base "$BASE_BRANCH" --head "$CURRENT_BRANCH" --fill --body-file "$BODY_FILE"
  fi
  PR_NUMBER="$(resolve_pr_number_for_head_branch "$CURRENT_BRANCH")"
fi

if [[ -z "$PR_NUMBER" ]]; then
  echo "[FAIL] open-task-pr"
  echo " - could not resolve PR number after publish"
  exit 1
fi

PR_JSON="$(gh pr view "$PR_NUMBER" --json number,url,headRefOid,isDraft)"
ensure_runtime_dirs "$TASK_ID"
{
  echo "pr_number=$(printf '%s' "$PR_JSON" | jq -r '.number')"
  echo "pr_url=$(printf '%s' "$PR_JSON" | jq -r '.url')"
  echo "pr_status=$(printf '%s' "$PR_JSON" | jq -r '.isDraft | if . then "draft" else "open" end')"
  echo "head_sha=$(printf '%s' "$PR_JSON" | jq -r '.headRefOid')"
  echo "published_branch=$CURRENT_BRANCH"
} > "$(pr_state_file "$TASK_ID")"

echo "[PASS] open-task-pr"
echo " - task=$TASK_ID"
echo " - pr=$PR_NUMBER"
