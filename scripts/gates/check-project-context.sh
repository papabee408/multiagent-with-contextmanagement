#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTEXT_DIR="$ROOT_DIR/docs/context"
PROJECT_FILE="$CONTEXT_DIR/PROJECT.md"
CONVENTIONS_FILE="$CONTEXT_DIR/CONVENTIONS.md"
ARCHITECTURE_FILE="$CONTEXT_DIR/ARCHITECTURE.md"
RULES_FILE="$CONTEXT_DIR/RULES.md"
GATES_FILE="$CONTEXT_DIR/GATES.md"
DEFAULT_TEMPLATE_SLUG="context+MultiAgentDev"

trim() {
  local value="${1:-}"
  printf '%s' "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

is_placeholder_text() {
  local value
  value="$(lower "$(trim "${1:-}")")"

  case "$value" in
    ""|"tbd"|"todo"|"replace-me"|"placeholder"|"fill-me"|"required")
      return 0
      ;;
  esac

  if [[ "$value" == *"<replace"* || "$value" == *"(required)"* || "$value" == *"fill this"* ]]; then
    return 0
  fi

  return 1
}

field_value() {
  local file="$1"
  local section="$2"
  local key="$3"

  awk -v section="$section" -v key="$key" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section {
      prefix = "- " key ":"
      if (index($0, prefix) == 1) {
        line = substr($0, length(prefix) + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

section_first_content() {
  local file="$1"
  local section="$2"

  awk -v section="$section" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "") {
        print line
        exit
      }
    }
  ' "$file"
}

require_section() {
  local file="$1"
  local section="$2"
  local label="$3"

  if ! grep -Fxq "$section" "$file"; then
    failures+=("$label:missing-section(${section})")
  fi
}

require_nonempty_section() {
  local file="$1"
  local section="$2"
  local label="$3"
  local value

  value="$(section_first_content "$file" "$section")"
  if is_placeholder_text "$value"; then
    failures+=("$label:empty-section(${section})")
  fi
}

require_gates_item() {
  local file="$1"
  local item="$2"
  local label="$3"

  if ! grep -Fq "\`$item\`" "$file"; then
    failures+=("$label:missing-gates-item($item)")
  fi
}

scan_forbidden_patterns() {
  local file="$1"
  local label="$2"
  local -a patterns=(
    'Discord Bot \(working title\)'
    'builder/index\.html'
    'builder/styles\.css'
    'builder/src/'
    '<replace'
  )

  for pattern in "${patterns[@]}"; do
    if grep -Eq "$pattern" "$file"; then
      failures+=("$label:contains-placeholder-or-stale-template-content")
      return
    fi
  done
}

failures=()

required_files=(
  "$PROJECT_FILE:PROJECT.md"
  "$CONVENTIONS_FILE:CONVENTIONS.md"
  "$ARCHITECTURE_FILE:ARCHITECTURE.md"
  "$RULES_FILE:RULES.md"
  "$GATES_FILE:GATES.md"
)

for entry in "${required_files[@]}"; do
  file="${entry%%:*}"
  label="${entry#*:}"
  if [[ ! -f "$file" ]]; then
    failures+=("$label:missing-file")
  fi
done

if [[ ! -f "$PROJECT_FILE" || ! -f "$CONVENTIONS_FILE" || ! -f "$ARCHITECTURE_FILE" || ! -f "$RULES_FILE" ]]; then
  echo "[FAIL] project-context"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

require_section "$PROJECT_FILE" "## Identity" "PROJECT.md"
require_section "$PROJECT_FILE" "## Product" "PROJECT.md"
require_section "$PROJECT_FILE" "## Stack" "PROJECT.md"
require_section "$PROJECT_FILE" "## Constraints" "PROJECT.md"
require_section "$PROJECT_FILE" "## Working Agreements" "PROJECT.md"
require_section "$CONVENTIONS_FILE" "## Reuse First" "CONVENTIONS.md"
require_section "$CONVENTIONS_FILE" "## Configuration and Constants" "CONVENTIONS.md"
require_section "$CONVENTIONS_FILE" "## Components and Modules" "CONVENTIONS.md"
require_section "$CONVENTIONS_FILE" "## Tests and Change Hygiene" "CONVENTIONS.md"
require_section "$ARCHITECTURE_FILE" "## System Map" "ARCHITECTURE.md"
require_section "$ARCHITECTURE_FILE" "## Layers" "ARCHITECTURE.md"
require_section "$ARCHITECTURE_FILE" "## Dependency Direction" "ARCHITECTURE.md"
require_section "$ARCHITECTURE_FILE" "## Placement Guide" "ARCHITECTURE.md"
require_section "$RULES_FILE" "## Scope and RQ" "RULES.md"
require_section "$RULES_FILE" "## Reuse and Hardcoding" "RULES.md"
require_section "$RULES_FILE" "## Architecture Fit" "RULES.md"
require_section "$RULES_FILE" "## Testing" "RULES.md"
require_section "$GATES_FILE" "## Gate 항목" "GATES.md"
require_section "$GATES_FILE" "## 실행 커맨드" "GATES.md"
require_section "$GATES_FILE" "## 완료 선언 규칙" "GATES.md"
require_section "$GATES_FILE" "## 실패 대응" "GATES.md"

require_nonempty_section "$PROJECT_FILE" "## Product" "PROJECT.md"
require_nonempty_section "$PROJECT_FILE" "## Stack" "PROJECT.md"
require_nonempty_section "$PROJECT_FILE" "## Constraints" "PROJECT.md"
require_nonempty_section "$PROJECT_FILE" "## Working Agreements" "PROJECT.md"
require_nonempty_section "$CONVENTIONS_FILE" "## Reuse First" "CONVENTIONS.md"
require_nonempty_section "$CONVENTIONS_FILE" "## Configuration and Constants" "CONVENTIONS.md"
require_nonempty_section "$CONVENTIONS_FILE" "## Components and Modules" "CONVENTIONS.md"
require_nonempty_section "$CONVENTIONS_FILE" "## Tests and Change Hygiene" "CONVENTIONS.md"
require_nonempty_section "$ARCHITECTURE_FILE" "## System Map" "ARCHITECTURE.md"
require_nonempty_section "$ARCHITECTURE_FILE" "## Layers" "ARCHITECTURE.md"
require_nonempty_section "$ARCHITECTURE_FILE" "## Dependency Direction" "ARCHITECTURE.md"
require_nonempty_section "$ARCHITECTURE_FILE" "## Placement Guide" "ARCHITECTURE.md"
require_nonempty_section "$RULES_FILE" "## Scope and RQ" "RULES.md"
require_nonempty_section "$RULES_FILE" "## Reuse and Hardcoding" "RULES.md"
require_nonempty_section "$RULES_FILE" "## Architecture Fit" "RULES.md"
require_nonempty_section "$RULES_FILE" "## Testing" "RULES.md"
require_nonempty_section "$GATES_FILE" "## Gate 항목" "GATES.md"
require_nonempty_section "$GATES_FILE" "## 실행 커맨드" "GATES.md"
require_nonempty_section "$GATES_FILE" "## 완료 선언 규칙" "GATES.md"
require_nonempty_section "$GATES_FILE" "## 실패 대응" "GATES.md"

project_name="$(field_value "$PROJECT_FILE" "## Identity" "project-name")"
repo_slug="$(field_value "$PROJECT_FILE" "## Identity" "repo-slug")"
product_type="$(field_value "$PROJECT_FILE" "## Identity" "product-type")"
repo_slug_lc="$(lower "$repo_slug")"
root_basename_lc="$(lower "$(basename "$ROOT_DIR")")"
default_template_slug_lc="$(lower "$DEFAULT_TEMPLATE_SLUG")"

if is_placeholder_text "$project_name"; then
  failures+=("PROJECT.md:missing-project-name")
fi

if is_placeholder_text "$repo_slug"; then
  failures+=("PROJECT.md:missing-repo-slug")
elif [[ "$repo_slug_lc" == "$default_template_slug_lc" && "$root_basename_lc" != "$default_template_slug_lc" ]]; then
  failures+=("PROJECT.md:stale-template-repo-slug($repo_slug)")
fi

if is_placeholder_text "$product_type"; then
  failures+=("PROJECT.md:missing-product-type")
fi

scan_forbidden_patterns "$PROJECT_FILE" "PROJECT.md"
scan_forbidden_patterns "$CONVENTIONS_FILE" "CONVENTIONS.md"
scan_forbidden_patterns "$ARCHITECTURE_FILE" "ARCHITECTURE.md"
scan_forbidden_patterns "$RULES_FILE" "RULES.md"
scan_forbidden_patterns "$GATES_FILE" "GATES.md"

for gate in project-context brief plan handoffs role-chain test-matrix scope file-size tests secrets; do
  require_gates_item "$GATES_FILE" "$gate" "GATES.md"
done

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] project-context"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] project-context"
