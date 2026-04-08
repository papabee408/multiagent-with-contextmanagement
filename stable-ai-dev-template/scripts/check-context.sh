#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

failures=()

require_file() {
  local relative_path="$1"
  if [[ ! -f "$ROOT_DIR/$relative_path" ]]; then
    failures+=("missing-file($relative_path)")
  fi
}

require_key() {
  local file="$1"
  local section="$2"
  local key="$3"
  local label="$4"
  local value

  value="$(section_key_value "$file" "$section" "$key")"
  if placeholder_like "$value"; then
    failures+=("$label:missing-$key")
  fi
}

require_section_first_content() {
  local file="$1"
  local section="$2"
  local label="$3"
  local value

  value="$(section_bullet_values "$file" "$section" | head -n 1)"
  if placeholder_like "$value"; then
    failures+=("$label:empty-section($section)")
  fi
}

require_section_first_backtick_value() {
  local file="$1"
  local section="$2"
  local label="$3"
  local value

  value="$(section_backtick_values "$file" "$section" | head -n 1)"
  if placeholder_like "$value"; then
    failures+=("$label:missing-entry($section)")
  fi
}

require_file "docs/context/PROJECT.md"
require_file "docs/context/ARCHITECTURE.md"
require_file "docs/context/CONVENTIONS.md"
require_file "docs/context/CI_PROFILE.md"
require_file "docs/context/CURRENT.md"
require_file "docs/context/DECISIONS.md"

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] context"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

PROJECT_FILE="$ROOT_DIR/docs/context/PROJECT.md"
ARCH_FILE="$ROOT_DIR/docs/context/ARCHITECTURE.md"
CONVENTIONS_FILE="$ROOT_DIR/docs/context/CONVENTIONS.md"
CI_PROFILE_FILE="$ROOT_DIR/docs/context/CI_PROFILE.md"

require_key "$PROJECT_FILE" "## Identity" "project-name" "PROJECT.md"
require_key "$PROJECT_FILE" "## Identity" "repo-slug" "PROJECT.md"
require_key "$PROJECT_FILE" "## Identity" "primary-users" "PROJECT.md"
require_section_first_content "$PROJECT_FILE" "## Product Goal" "PROJECT.md"
require_section_first_content "$PROJECT_FILE" "## Constraints" "PROJECT.md"
require_section_first_content "$PROJECT_FILE" "## Quality Bar" "PROJECT.md"
require_section_first_content "$PROJECT_FILE" "## Critical Flows" "PROJECT.md"

require_key "$ARCH_FILE" "## System Map" "entry/application" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## System Map" "domain/feature" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## System Map" "infrastructure/integration" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## System Map" "shared" "ARCHITECTURE.md"
require_section_first_content "$ARCH_FILE" "## Module Boundaries" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## Dependency Rules" "allowed" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## Dependency Rules" "forbidden" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## Placement Rules" "new business logic" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## Placement Rules" "new IO or adapter code" "ARCHITECTURE.md"
require_key "$ARCH_FILE" "## Placement Rules" "new shared abstractions" "ARCHITECTURE.md"

require_section_first_content "$CONVENTIONS_FILE" "## Scope Discipline" "CONVENTIONS.md"
require_section_first_content "$CONVENTIONS_FILE" "## Reuse And Config" "CONVENTIONS.md"
require_section_first_content "$CONVENTIONS_FILE" "## Testing" "CONVENTIONS.md"
require_section_first_content "$CONVENTIONS_FILE" "## Visual Changes" "CONVENTIONS.md"

require_key "$CI_PROFILE_FILE" "## Project Profile" "platform" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Project Profile" "stack" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Project Profile" "package-manager" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Git / PR Policy" "git-host" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Git / PR Policy" "default-base-branch" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Git / PR Policy" "default-branch-strategy" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Git / PR Policy" "task-branch-pattern" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Git / PR Policy" "required-check-resolution" "CI_PROFILE.md"
require_key "$CI_PROFILE_FILE" "## Git / PR Policy" "merge-method" "CI_PROFILE.md"
require_section_first_backtick_value "$CI_PROFILE_FILE" "## Required Check Fallback" "CI_PROFILE.md"
require_section_first_backtick_value "$CI_PROFILE_FILE" "## PR Fast Checks" "CI_PROFILE.md"

ACTIVE_TASK="$(active_task_value)"
if [[ -n "$ACTIVE_TASK" && ! -f "$(task_file "$ACTIVE_TASK")" ]]; then
  failures+=("active-task-missing-task-file($ACTIVE_TASK)")
fi

CURRENT_TASK="$(current_snapshot_active_task_value)"
if [[ -n "$CURRENT_TASK" && ! -f "$(task_file "$CURRENT_TASK")" ]]; then
  failures+=("current-snapshot-missing-task-file($CURRENT_TASK)")
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] context"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] context"
