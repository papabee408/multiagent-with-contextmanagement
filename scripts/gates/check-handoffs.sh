#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh" "${1:-}"

section_value() {
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

is_valid_utc_timestamp() {
  local value="$1"
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

require_file() {
  local file="$1"
  local label="$2"

  if [[ ! -f "$file" ]]; then
    failures+=("$label:missing-file")
    return 1
  fi

  return 0
}

validate_keys() {
  local file="$1"
  local section="$2"
  local prefix="$3"
  shift 3

  for key in "$@"; do
    value="$(section_value "$file" "$section" "$key")"
    if is_placeholder_text "$value"; then
      failures+=("$prefix:missing-${key// /-}")
    fi
  done
}

validate_digest_block() {
  local file="$1"
  local prefix="$2"
  local expected_brief_sha="$3"
  local expected_plan_sha="$4"
  local expected_project_sha="$5"
  local expected_architecture_sha="$6"
  local expected_gates_sha="$7"
  local brief_sha
  local plan_sha
  local project_sha
  local architecture_sha
  local gates_sha
  local generated_at

  brief_sha="$(section_value "$file" "## Source Digest" "brief-sha")"
  plan_sha="$(section_value "$file" "## Source Digest" "plan-sha")"
  project_sha="$(section_value "$file" "## Source Digest" "project-context-sha")"
  architecture_sha="$(section_value "$file" "## Source Digest" "architecture-sha")"
  gates_sha="$(section_value "$file" "## Source Digest" "gates-sha")"
  generated_at="$(section_value "$file" "## Source Digest" "generated-at-utc")"

  if is_placeholder_text "$brief_sha"; then
    failures+=("$prefix:missing-brief-sha")
  elif [[ "$brief_sha" != "$expected_brief_sha" ]]; then
    failures+=("$prefix:stale-brief-sha")
  fi

  if is_placeholder_text "$plan_sha"; then
    failures+=("$prefix:missing-plan-sha")
  elif [[ "$plan_sha" != "$expected_plan_sha" ]]; then
    failures+=("$prefix:stale-plan-sha")
  fi

  if is_placeholder_text "$project_sha"; then
    failures+=("$prefix:missing-project-context-sha")
  elif [[ "$project_sha" != "$expected_project_sha" ]]; then
    failures+=("$prefix:stale-project-context-sha")
  fi

  if is_placeholder_text "$architecture_sha"; then
    failures+=("$prefix:missing-architecture-sha")
  elif [[ "$architecture_sha" != "$expected_architecture_sha" ]]; then
    failures+=("$prefix:stale-architecture-sha")
  fi

  if is_placeholder_text "$gates_sha"; then
    failures+=("$prefix:missing-gates-sha")
  elif [[ "$gates_sha" != "$expected_gates_sha" ]]; then
    failures+=("$prefix:stale-gates-sha")
  fi

  if is_placeholder_text "$generated_at"; then
    failures+=("$prefix:missing-generated-at-utc")
  elif ! is_valid_utc_timestamp "$generated_at"; then
    failures+=("$prefix:invalid-generated-at-utc($generated_at)")
  fi
}

failures=()

BRIEF_FILE="$FEATURE_DIR/brief.md"
PROJECT_FILE="$ROOT_DIR/docs/context/PROJECT.md"
ARCHITECTURE_FILE="$ROOT_DIR/docs/context/ARCHITECTURE.md"
GATES_FILE="$ROOT_DIR/docs/context/GATES.md"

IMPLEMENTER_FILE="$FEATURE_DIR/implementer-handoff.md"
TESTER_FILE="$FEATURE_DIR/tester-handoff.md"
REVIEWER_FILE="$FEATURE_DIR/reviewer-handoff.md"
SECURITY_FILE="$FEATURE_DIR/security-handoff.md"

EXPECTED_BRIEF_SHA="$(file_digest_or_missing "$BRIEF_FILE")"
EXPECTED_PLAN_SHA="$(file_digest_or_missing "$PLAN_FILE")"
EXPECTED_PROJECT_SHA="$(file_digest_or_missing "$PROJECT_FILE")"
EXPECTED_ARCHITECTURE_SHA="$(file_digest_or_missing "$ARCHITECTURE_FILE")"
EXPECTED_GATES_SHA="$(file_digest_or_missing "$GATES_FILE")"

if require_file "$IMPLEMENTER_FILE" "implementer-handoff.md"; then
  validate_digest_block "$IMPLEMENTER_FILE" "implementer-handoff" \
    "$EXPECTED_BRIEF_SHA" \
    "$EXPECTED_PLAN_SHA" \
    "$EXPECTED_PROJECT_SHA" \
    "$EXPECTED_ARCHITECTURE_SHA" \
    "$EXPECTED_GATES_SHA"
  validate_keys "$IMPLEMENTER_FILE" "## Scope" "implementer-handoff" \
    "rq_covered" \
    "execution mode" \
    "target files" \
    "task order" \
    "out-of-scope reminders"
  validate_keys "$IMPLEMENTER_FILE" "## Constraints" "implementer-handoff" \
    "architecture placement" \
    "dependency constraints" \
    "reuse / config directives"
  validate_keys "$IMPLEMENTER_FILE" "## Acceptance" "implementer-handoff" \
    "done when"
fi

if require_file "$TESTER_FILE" "tester-handoff.md"; then
  validate_digest_block "$TESTER_FILE" "tester-handoff" \
    "$EXPECTED_BRIEF_SHA" \
    "$EXPECTED_PLAN_SHA" \
    "$EXPECTED_PROJECT_SHA" \
    "$EXPECTED_ARCHITECTURE_SHA" \
    "$EXPECTED_GATES_SHA"
  validate_keys "$TESTER_FILE" "## Coverage" "tester-handoff" \
    "execution mode" \
    "rq coverage" \
    "required scenarios" \
    "priority risks"
  validate_keys "$TESTER_FILE" "## Setup" "tester-handoff" \
    "fixtures / mocks / setup" \
    "test edit policy" \
    "execution notes / commands"
  validate_keys "$TESTER_FILE" "## Acceptance" "tester-handoff" \
    "matrix expectations" \
    "trivial-mode note"
fi

if require_file "$REVIEWER_FILE" "reviewer-handoff.md"; then
  validate_digest_block "$REVIEWER_FILE" "reviewer-handoff" \
    "$EXPECTED_BRIEF_SHA" \
    "$EXPECTED_PLAN_SHA" \
    "$EXPECTED_PROJECT_SHA" \
    "$EXPECTED_ARCHITECTURE_SHA" \
    "$EXPECTED_GATES_SHA"
  validate_keys "$REVIEWER_FILE" "## Focus" "reviewer-handoff" \
    "execution mode" \
    "regression hotspots" \
    "approval target" \
    "architecture / reuse focus" \
    "scope drift watchpoints"
  validate_keys "$REVIEWER_FILE" "## Quality Checklist" "reviewer-handoff" \
    "reuse / componentization" \
    "hardcoding / config centralization" \
    "performance / waste watchpoints"
  validate_keys "$REVIEWER_FILE" "## Acceptance" "reviewer-handoff" \
    "fail conditions" \
    "approval binding"
fi

if require_file "$SECURITY_FILE" "security-handoff.md"; then
  validate_digest_block "$SECURITY_FILE" "security-handoff" \
    "$EXPECTED_BRIEF_SHA" \
    "$EXPECTED_PLAN_SHA" \
    "$EXPECTED_PROJECT_SHA" \
    "$EXPECTED_ARCHITECTURE_SHA" \
    "$EXPECTED_GATES_SHA"
  validate_keys "$SECURITY_FILE" "## Focus" "security-handoff" \
    "execution mode" \
    "validation / auth focus" \
    "approval target" \
    "secrets / config touchpoints" \
    "abuse / failure paths"
  validate_keys "$SECURITY_FILE" "## Acceptance" "security-handoff" \
    "fail conditions" \
    "approval binding"
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] handoffs"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] handoffs"
