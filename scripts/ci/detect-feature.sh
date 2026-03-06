#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANUAL_FEATURE_ID="${1:-}"

cd "$ROOT_DIR"

if [[ -n "$MANUAL_FEATURE_ID" ]]; then
  if [[ "$MANUAL_FEATURE_ID" == "_template" ]]; then
    echo "[FAIL] feature-id cannot be _template" >&2
    exit 1
  fi
  if [[ ! -d "docs/features/$MANUAL_FEATURE_ID" ]]; then
    echo "[FAIL] feature packet not found: docs/features/$MANUAL_FEATURE_ID" >&2
    exit 1
  fi
  printf '%s\n' "$MANUAL_FEATURE_ID"
  exit 0
fi

collect_changed_files() {
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    base_ref="origin/${GITHUB_BASE_REF}"
    if git show-ref --verify --quiet "refs/remotes/${base_ref}"; then
      git diff --name-only --relative "${base_ref}...HEAD"
      return 0
    fi
  fi

  {
    git diff --name-only --relative
    git diff --name-only --relative --cached
    git ls-files --others --exclude-standard
  } | sed '/^$/d' | sort -u
}

mapfile_output="$(collect_changed_files)"

feature_ids="$(printf '%s\n' "$mapfile_output" \
  | awk -F/ '/^docs\/features\/[^/]+\// { if ($3 != "_template") print $3 }' \
  | sort -u)"

feature_count="$(printf '%s\n' "$feature_ids" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

if [[ "$feature_count" == "0" ]]; then
  echo "[FAIL] no changed feature packet detected under docs/features/<feature-id>/" >&2
  echo "       map this change to exactly one feature packet before merge." >&2
  exit 1
fi

if [[ "$feature_count" != "1" ]]; then
  echo "[FAIL] exactly one feature packet must be changed per PR." >&2
  printf ' - %s\n' $feature_ids >&2
  exit 1
fi

printf '%s\n' "$feature_ids"
