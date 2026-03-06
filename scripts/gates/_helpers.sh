#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FEATURE_ID="${1:-}"
FEATURE_DIR="$ROOT_DIR/docs/features/$FEATURE_ID"
PLAN_FILE="$FEATURE_DIR/plan.md"
BASELINE_FILE="$FEATURE_DIR/.baseline-changes.txt"

if [[ -z "$FEATURE_ID" ]]; then
  echo "[ERROR] feature-id is required" >&2
  exit 1
fi

if [[ ! -d "$FEATURE_DIR" ]]; then
  echo "[ERROR] feature packet dir missing: $FEATURE_DIR" >&2
  exit 1
fi

changed_files() {
  local -a files=()
  local range="${GATE_DIFF_RANGE:-}"

  if [[ -n "$range" ]]; then
    git -C "$ROOT_DIR" diff --name-only --relative "$range"
    return 0
  fi

  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    local base_ref="origin/${GITHUB_BASE_REF}"
    if git -C "$ROOT_DIR" show-ref --verify --quiet "refs/remotes/${base_ref}"; then
      git -C "$ROOT_DIR" diff --name-only --relative "${base_ref}...HEAD"
      return 0
    fi
  fi

  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(git -C "$ROOT_DIR" diff --name-only --relative)

  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(git -C "$ROOT_DIR" diff --name-only --relative --cached)

  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(git -C "$ROOT_DIR" ls-files --others --exclude-standard)

  if [[ ${#files[@]} -eq 0 && "$(git -C "$ROOT_DIR" rev-list --count HEAD)" -gt 1 ]]; then
    git -C "$ROOT_DIR" diff --name-only --relative HEAD~1..HEAD
    return 0
  fi

  if [[ -f "$BASELINE_FILE" ]]; then
    current_tmp="$(mktemp)"
    filtered_tmp="$(mktemp)"

    printf '%s\n' "${files[@]}" | sort -u > "$current_tmp"
    grep -Fxv -f "$BASELINE_FILE" "$current_tmp" > "$filtered_tmp" || true
    cat "$filtered_tmp"
    rm -f "$current_tmp" "$filtered_tmp"
    return 0
  fi

  printf '%s\n' "${files[@]}" | sort -u
}

# Extract backtick-wrapped file paths from plan.md target files section.
allowed_files_from_plan() {
  if [[ ! -f "$PLAN_FILE" ]]; then
    return 0
  fi

  awk '
    /^## Scope/ { in_scope=1; next }
    /^## / && in_scope { in_scope=0 }
    in_scope && /target files:/ { in_targets=1; next }
    in_scope && /out-of-scope files:/ { in_targets=0 }
    in_scope && in_targets && /`[^`]+`/ {
      while (match($0, /`[^`]+`/)) {
        value = substr($0, RSTART + 1, RLENGTH - 2)
        print value
        $0 = substr($0, RSTART + RLENGTH)
      }
    }
  ' "$PLAN_FILE" | sed '/^$/d' | sort -u
}

is_doc_file() {
  local path="$1"
  [[ "$path" == docs/* || "$path" == "AGENTS.md" || "$path" == "README.md" ]]
}
