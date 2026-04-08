#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/_git_change_helpers.sh"
MANUAL_FEATURE_ID="${1:-}"
STABLE_TEMPLATE_SENTINEL="__stable_ai_dev_template__"

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
  git_changed_files_for_repo "$ROOT_DIR" "${GATE_DIFF_RANGE:-}" "${GITHUB_BASE_REF:-}"
}

mapfile_output="$(collect_changed_files)"

stable_template_change_count="$(printf '%s\n' "$mapfile_output" \
  | awk '
      /^stable-ai-dev-template\// { count += 1 }
      END { print count + 0 }
    ')"

if [[ "$stable_template_change_count" -gt 0 ]]; then
  printf '%s\n' "$STABLE_TEMPLATE_SENTINEL"
  exit 0
fi

feature_ids="$(printf '%s\n' "$mapfile_output" \
  | awk -F/ '
      index($0, "docs/features/") == 1 && NF >= 3 {
        if ($3 != "_template") print $3
      }
    ' \
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
