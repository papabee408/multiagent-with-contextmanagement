#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

alert_count=0
ok_count=0

say_ok() {
  echo "[OK] $1"
  ok_count=$((ok_count + 1))
}

say_alert() {
  echo "[ALERT] $1"
  alert_count=$((alert_count + 1))
}

detect_default_branch() {
  local branch=""

  branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [[ -z "$branch" ]]; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    branch="main"
  fi

  printf '%s\n' "$branch"
}

parse_github_repo() {
  local remote_url="$1"
  local owner=""
  local repo=""

  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  fi

  printf '%s\n%s\n' "$owner" "$repo"
}

echo "== Project Setup Check =="

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  say_alert "Not a Git repository. Connect Git/GitHub before starting project work."
  echo " - Example: git init && git remote add origin <github-url>"
  echo ""
  echo "Setup Summary: ALERT (${alert_count} issues)"
  exit 1
fi

say_ok "Git repository detected"

origin_url="$(git config --get remote.origin.url || true)"
if [[ -z "$origin_url" ]]; then
  say_alert "Missing origin remote. Connect a GitHub remote."
else
  if [[ "$origin_url" =~ github\.com[:/] ]]; then
    say_ok "GitHub origin remote detected ($origin_url)"
  else
    say_alert "origin remote is not GitHub ($origin_url)"
  fi
fi

if [[ -f ".github/workflows/gates.yml" ]]; then
  say_ok "Gates workflow file exists"
else
  say_alert "Missing .github/workflows/gates.yml. CI enforcement cannot run."
fi

default_branch="$(detect_default_branch)"

if ! command -v gh >/dev/null 2>&1; then
  say_alert "gh CLI is not installed. Skipping automatic verification of GitHub settings."
  echo " - Manual check #1: Settings > Actions > Allow all actions"
  echo " - Manual check #2: Settings > Branches > ${default_branch} protection > Add required check 'Gates'"
  echo ""
  if [[ "$alert_count" -gt 0 ]]; then
    echo "Setup Summary: ALERT (${alert_count} issues)"
  else
    echo "Setup Summary: OK (${ok_count} checks)"
  fi
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  say_alert "gh is not authenticated. Skipping automatic verification of GitHub settings."
  echo " - Run: gh auth login"
  echo ""
  if [[ "$alert_count" -gt 0 ]]; then
    echo "Setup Summary: ALERT (${alert_count} issues)"
  else
    echo "Setup Summary: OK (${ok_count} checks)"
  fi
  exit 1
fi

owner=""
repo=""
if [[ -n "$origin_url" ]]; then
  mapfile -t parsed < <(parse_github_repo "$origin_url")
  owner="${parsed[0]}"
  repo="${parsed[1]}"
fi

if [[ -z "$owner" || -z "$repo" ]]; then
  say_alert "Could not parse GitHub owner/repo from origin URL."
  echo ""
  echo "Setup Summary: ALERT (${alert_count} issues)"
  exit 1
fi

actions_enabled="$(gh api "repos/${owner}/${repo}/actions/permissions" --jq '.enabled' 2>/dev/null || true)"
if [[ "$actions_enabled" == "true" ]]; then
  say_ok "GitHub Actions enabled"
else
  say_alert "GitHub Actions is disabled. Enable it in Settings > Actions."
fi

required_checks="$(gh api "repos/${owner}/${repo}/branches/${default_branch}/protection" --jq '.required_status_checks.checks[].context' 2>/dev/null || true)"
if printf '%s\n' "$required_checks" | grep -Fxq "Gates"; then
  say_ok "Branch protection required check: Gates"
else
  say_alert "Branch protection is missing required check 'Gates' (branch: ${default_branch})."
fi

echo ""
if [[ "$alert_count" -gt 0 ]]; then
  echo "Setup Summary: ALERT (${alert_count} issues)"
  exit 1
else
  echo "Setup Summary: OK (${ok_count} checks)"
  exit 0
fi
