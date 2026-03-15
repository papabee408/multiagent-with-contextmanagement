#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"
FEATURE_ID="${1:-}"

if [[ -z "$FEATURE_ID" && -f "$ACTIVE_FEATURE_FILE" ]]; then
  FEATURE_ID="$(tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE")"
fi

if [[ -z "$FEATURE_ID" ]]; then
  echo "Usage: scripts/sync-handoffs.sh <feature-id>"
  echo "Or set .context/active_feature first."
  exit 1
fi

source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"

BRIEF_FILE="$FEATURE_DIR/brief.md"
PLAN_FILE="$FEATURE_DIR/plan.md"
IMPLEMENTER_FILE="$FEATURE_DIR/implementer-handoff.md"
TESTER_FILE="$FEATURE_DIR/tester-handoff.md"
REVIEWER_FILE="$FEATURE_DIR/reviewer-handoff.md"
SECURITY_FILE="$FEATURE_DIR/security-handoff.md"
TEST_MATRIX_FILE="$FEATURE_DIR/test-matrix.md"
PROJECT_FILE="$ROOT_DIR/docs/context/PROJECT.md"
ARCHITECTURE_FILE="$ROOT_DIR/docs/context/ARCHITECTURE.md"
GATES_FILE="$ROOT_DIR/docs/context/GATES.md"
SYNC_SCRIPT_FILE="$ROOT_DIR/scripts/sync-handoffs.sh"

trim() {
  local value="${1:-}"
  printf '%s' "$value" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

normalize_inline() {
  local value="${1:-}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="$(printf '%s' "$value" | tr -s ' ')"
  trim "$value"
}

join_lines() {
  local delimiter="${1:-; }"
  shift || true
  awk -v delim="$delimiter" '
    BEGIN { first = 1 }
    {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "") next
      if (!first) printf "%s", delim
      printf "%s", line
      first = 0
    }
  '
}

value_or_tbd() {
  local value
  value="$(normalize_inline "${1:-}")"
  if is_placeholder_text "$value"; then
    printf 'TBD'
    return
  fi
  printf '%s' "$value"
}

hash_or_tbd() {
  local path="$1"
  if [[ -f "$path" ]]; then
    sha256_file "$path"
    return
  fi
  printf 'TBD'
}

brief_section_value() {
  local section="$1"
  local key="$2"

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
  ' "$BRIEF_FILE"
}

section_first_line() {
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

brief_rq_summary() {
  while IFS= read -r rq; do
    [[ -n "$rq" ]] || continue
    description="$(awk -v rq="$rq" '
      /^## Requirements \(RQ\)/ { in_rq = 1; next }
      /^## / && in_rq { in_rq = 0 }
      in_rq && index($0, "`" rq "`") {
        line = $0
        sub(/^.*:[[:space:]]*/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    ' "$BRIEF_FILE")"
    description="$(value_or_tbd "$description")"
    printf '`%s`: %s\n' "$rq" "$description"
  done < <(brief_rq_ids)
}

brief_rq_ids_inline() {
  brief_rq_ids | join_lines ', '
}

tester_required_scenarios() {
  while IFS= read -r rq; do
    [[ -n "$rq" ]] || continue
    printf '%s normal/error/boundary coverage\n' "$rq"
  done < <(brief_rq_ids)
}

tester_test_edit_policy() {
  if [[ "$(workflow_mode_from_brief)" == "full" ]]; then
    printf '%s' "implementer owns baseline test updates; tester may strengthen \`tests/**\` only when coverage gaps remain after implementation"
    return 0
  fi

  printf '%s' "implementer owns all test edits in lite mode; tester reports coverage gaps back to implementer instead of editing tests"
}

plan_section_value() {
  local section="$1"
  local key="$2"

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
  ' "$PLAN_FILE"
}

scope_out_of_scope_lines() {
  awk '
    /^## Scope/ { in_scope = 1; next }
    /^## / && in_scope { in_scope = 0 }
    in_scope && /^- out-of-scope files:/ { in_out = 1; next }
    in_scope && in_out {
      if ($0 ~ /^[[:space:]]*-[[:space:]]+/) {
        line = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        next
      }
      if ($0 ~ /^- / || $0 ~ /^## /) {
        in_out = 0
      }
    }
  ' "$PLAN_FILE" | sed '/^$/d'
}

task_card_titles() {
  awk '
    /^## Task Cards/ { in_cards = 1; next }
    /^## / && in_cards { in_cards = 0 }
    in_cards && /^### / {
      line = substr($0, 5)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
    }
  ' "$PLAN_FILE"
}

task_card_done_whens() {
  awk '
    /^## Task Cards/ { in_cards = 1; next }
    /^## / && in_cards { in_cards = 0 }
    in_cards {
      if (index($0, "- done when:") == 1) {
        line = substr($0, length("- done when:") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "") {
          print line
        }
      }
    }
  ' "$PLAN_FILE"
}

parallel_task_package_summary() {
  if [[ "$(implementer_mode_from_plan)" != "parallel" ]]; then
    printf '%s' "serial mode"
    return 0
  fi

  task_card_titles | join_lines '; '
}

reviewer_performance_watchpoints() {
  printf '%s\n' \
    "$(plan_section_value "## Architecture Notes" "target layer / owning module")" \
    "$(plan_section_value "## Architecture Notes" "dependency constraints / forbidden imports")" \
    "avoid repeated expensive transforms/lookups or duplicated render/update paths inside touched files"
}

render_source_digest() {
  cat <<EOF
## Source Digest
- brief-sha: $(hash_or_tbd "$BRIEF_FILE")
- plan-sha: $(hash_or_tbd "$PLAN_FILE")
- project-context-sha: $(hash_or_tbd "$PROJECT_FILE")
- architecture-sha: $(hash_or_tbd "$ARCHITECTURE_FILE")
- gates-sha: $(hash_or_tbd "$GATES_FILE")
- sync-script-sha: $(hash_or_tbd "$SYNC_SCRIPT_FILE")
- generated-at-utc: $(utc_now)
EOF
}

render_implementer_handoff() {
  cat > "$IMPLEMENTER_FILE" <<EOF
# Implementer Handoff

> Generated by \`scripts/sync-handoffs.sh\`. Edit \`plan.md\` and rerun sync instead of hand-editing this file.

$(render_source_digest)

## Scope
- rq_covered: $(value_or_tbd "$(brief_rq_ids_inline)")
- workflow mode: $(value_or_tbd "$(workflow_mode_from_brief)")
- target files: $(value_or_tbd "$(allowed_files_from_plan | join_lines ', ')")
- task order: $(value_or_tbd "$(task_card_titles | join_lines ' -> ')")
- out-of-scope reminders: $(value_or_tbd "$(scope_out_of_scope_lines | join_lines '; ')")

## Constraints
- implementer mode: $(value_or_tbd "$(implementer_mode_from_plan)")
- merge owner: $(value_or_tbd "$(implementer_merge_owner_from_plan)")
- parallel worker packages: $(value_or_tbd "$(parallel_task_package_summary)")
- architecture placement: $(value_or_tbd "$(plan_section_value "## Architecture Notes" "target layer / owning module")")
- dependency constraints: $(value_or_tbd "$(plan_section_value "## Architecture Notes" "dependency constraints / forbidden imports")")
- reuse / config directives: $(value_or_tbd "$(printf '%s\n' \
    "$(plan_section_value "## Reuse and Config Plan" "existing abstractions to reuse")" \
    "$(plan_section_value "## Reuse and Config Plan" "extraction candidates for shared component/helper/module")" \
    "$(plan_section_value "## Reuse and Config Plan" "constants/config/env to centralize")" \
    "$(plan_section_value "## Reuse and Config Plan" "hardcoded values explicitly allowed")" | join_lines '; ')")

## Acceptance
- done when: $(value_or_tbd "$(task_card_done_whens | join_lines '; ')")

## Manual Notes
- Edit \`plan.md\` or \`brief.md\` and rerun \`scripts/sync-handoffs.sh\` if generated defaults need to change.
EOF
}

render_tester_handoff() {
  cat > "$TESTER_FILE" <<EOF
# Tester Handoff

> Generated by \`scripts/sync-handoffs.sh\`. Edit \`brief.md\` or \`plan.md\` and rerun sync instead of hand-editing this file.

$(render_source_digest)

## Coverage
- workflow mode: $(value_or_tbd "$(workflow_mode_from_brief)")
- rq coverage: $(value_or_tbd "$(brief_rq_summary | join_lines '; ')")
- required scenarios: $(value_or_tbd "$(tester_required_scenarios | join_lines '; ')")
- priority risks: $(value_or_tbd "$(printf '%s\n' \
    "$(section_first_line "$BRIEF_FILE" "## Constraints")" \
    "$(plan_section_value "## Architecture Notes" "dependency constraints / forbidden imports")" \
    "$(scope_out_of_scope_lines | join_lines '; ')" | join_lines '; ')")

## Setup
- fixtures / mocks / setup: $(value_or_tbd "$(printf '%s\n' \
    "$(brief_section_value "## Requirement Notes" "External dependencies")" \
    "$(brief_section_value "## Requirement Notes" "Existing modules/components/constants to reuse")" | join_lines '; ')")
- test edit policy: $(value_or_tbd "$(tester_test_edit_policy)")
- execution notes / commands: Run \`scripts/gates/check-tests.sh\`, then update \`test-matrix.md\` with the concrete test files you executed.

## Acceptance
- matrix expectations: every brief RQ must have a \`test-matrix.md\` row with concrete normal/error/boundary coverage, test file, and \`VERIFIED\` status before tester returns \`PASS\`

## Manual Notes
- Edit \`brief.md\` or \`plan.md\` and rerun \`scripts/sync-handoffs.sh\` if generated defaults need to change.
EOF
}

render_reviewer_handoff() {
  cat > "$REVIEWER_FILE" <<EOF
# Reviewer Handoff

> Generated by \`scripts/sync-handoffs.sh\`. Edit \`plan.md\` and rerun sync instead of hand-editing this file.

$(render_source_digest)

## Focus
- workflow mode: $(value_or_tbd "$(workflow_mode_from_brief)")
- regression hotspots: $(value_or_tbd "$(allowed_files_from_plan | join_lines ', ')")
- architecture / reuse focus: $(value_or_tbd "$(printf '%s\n' \
    "$(plan_section_value "## Architecture Notes" "target layer / owning module")" \
    "$(plan_section_value "## Reuse and Config Plan" "existing abstractions to reuse")" \
    "$(plan_section_value "## Reuse and Config Plan" "extraction candidates for shared component/helper/module")" | join_lines '; ')")
- scope drift watchpoints: $(value_or_tbd "$(scope_out_of_scope_lines | join_lines '; ')")

## Quality Checklist
- reuse / componentization: $(value_or_tbd "$(printf '%s\n' \
    "$(plan_section_value "## Reuse and Config Plan" "existing abstractions to reuse")" \
    "$(plan_section_value "## Reuse and Config Plan" "extraction candidates for shared component/helper/module")" | join_lines '; ')")
- hardcoding / config centralization: $(value_or_tbd "$(printf '%s\n' \
    "$(brief_section_value "## Requirement Notes" "Values/config that must not be hardcoded")" \
    "$(plan_section_value "## Reuse and Config Plan" "constants/config/env to centralize")" \
    "$(plan_section_value "## Reuse and Config Plan" "hardcoded values explicitly allowed")" | join_lines '; ')")
- performance / waste watchpoints: $(value_or_tbd "$(reviewer_performance_watchpoints | join_lines '; ')")

## Acceptance
- fail conditions: target files drift outside \`plan.md\` scope, dependency constraints are violated, reuse/componentization opportunities are ignored, centralized config is bypassed, or obvious performance waste is introduced

## Manual Notes
- Edit \`plan.md\` and rerun \`scripts/sync-handoffs.sh\` if generated defaults need to change.
EOF
}

render_security_handoff() {
  cat > "$SECURITY_FILE" <<EOF
# Security Handoff

> Generated by \`scripts/sync-handoffs.sh\`. Edit \`brief.md\` or \`plan.md\` and rerun sync instead of hand-editing this file.

$(render_source_digest)

## Focus
- workflow mode: $(value_or_tbd "$(workflow_mode_from_brief)")
- validation / auth focus: $(value_or_tbd "$(section_first_line "$BRIEF_FILE" "## Constraints")")
- secrets / config touchpoints: $(value_or_tbd "$(printf '%s\n' \
    "$(brief_section_value "## Requirement Notes" "Values/config that must not be hardcoded")" \
    "$(plan_section_value "## Reuse and Config Plan" "constants/config/env to centralize")" | join_lines '; ')")
- abuse / failure paths: $(value_or_tbd "$(printf '%s\n' \
    "$(section_first_line "$BRIEF_FILE" "## Non-goals")" \
    "$(plan_section_value "## Architecture Notes" "dependency constraints / forbidden imports")" \
    "$(scope_out_of_scope_lines | join_lines '; ')" | join_lines '; ')")

## Acceptance
- fail conditions: hardcoded values violate brief requirement notes, centralized config is bypassed, or forbidden dependency paths from \`plan.md\` are introduced

## Manual Notes
- Edit \`brief.md\` or \`plan.md\` and rerun \`scripts/sync-handoffs.sh\` if generated defaults need to change.
EOF
}

matrix_status_value() {
  if [[ ! -f "$TEST_MATRIX_FILE" ]]; then
    return 0
  fi

  awk '
    $0 == "## Status" { in_status = 1; next }
    in_status && /^## / { in_status = 0 }
    in_status && index($0, "- status:") == 1 {
      line = substr($0, length("- status:") + 1)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$TEST_MATRIX_FILE"
}

matrix_last_updated_value() {
  if [[ ! -f "$TEST_MATRIX_FILE" ]]; then
    return 0
  fi

  awk '
    $0 == "## Status" { in_status = 1; next }
    in_status && /^## / { in_status = 0 }
    in_status && index($0, "- last-updated-utc:") == 1 {
      line = substr($0, length("- last-updated-utc:") + 1)
      gsub(/`/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$TEST_MATRIX_FILE"
}

render_test_matrix() {
  local existing_rows_tmp
  local new_rows_tmp
  local preserve_verified=1
  local existing_status
  local existing_last_updated

  existing_rows_tmp="$(mktemp)"
  new_rows_tmp="$(mktemp)"
  trap 'rm -f "$existing_rows_tmp" "$new_rows_tmp"' RETURN

  if [[ -f "$TEST_MATRIX_FILE" ]]; then
    awk -F'|' '
      /^\|[[:space:]]*RQ-[0-9]+[[:space:]]*\|/ {
        rq = $2
        normal = $3
        error = $4
        boundary = $5
        test_file = $6
        status = $7
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", rq)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", normal)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", error)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", boundary)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", test_file)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
        print rq "\t" normal "\t" error "\t" boundary "\t" test_file "\t" status
      }
    ' "$TEST_MATRIX_FILE" > "$existing_rows_tmp"
  fi

  existing_status="$(normalize_inline "$(matrix_status_value)")"
  existing_last_updated="$(normalize_inline "$(matrix_last_updated_value)")"
  if [[ "$(printf '%s' "$existing_status" | tr '[:lower:]' '[:upper:]')" != "VERIFIED" ]]; then
    preserve_verified=0
  fi

  while IFS= read -r rq; do
    [[ -n "$rq" ]] || continue
    row="$(awk -F'\t' -v rq="$rq" '$1 == rq { print; exit }' "$existing_rows_tmp")"
    if [[ -n "$row" ]]; then
      IFS=$'\t' read -r _ existing_normal existing_error existing_boundary existing_test_file existing_row_status <<< "$row"
    else
      existing_normal=""
      existing_error=""
      existing_boundary=""
      existing_test_file=""
      existing_row_status=""
      preserve_verified=0
    fi

    if [[ -z "$existing_normal" || -z "$existing_error" || -z "$existing_boundary" || -z "$existing_test_file" ]]; then
      preserve_verified=0
    fi
    if [[ "$(printf '%s' "$existing_row_status" | tr '[:lower:]' '[:upper:]')" != "VERIFIED" ]]; then
      preserve_verified=0
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$rq" \
      "$existing_normal" \
      "$existing_error" \
      "$existing_boundary" \
      "$existing_test_file" \
      "$existing_row_status" >> "$new_rows_tmp"
  done < <(brief_rq_ids)

  while IFS=$'\t' read -r existing_rq _; do
    [[ -n "$existing_rq" ]] || continue
    if ! grep -Fqx "$existing_rq" <(brief_rq_ids); then
      preserve_verified=0
      break
    fi
  done < "$existing_rows_tmp"

  if [[ ! -s "$new_rows_tmp" ]]; then
    preserve_verified=0
  fi

  status_value="DRAFT"
  last_updated_value="$(utc_now)"
  if [[ "$preserve_verified" == "1" && -n "$existing_last_updated" && "$(printf '%s' "$existing_last_updated" | tr '[:lower:]' '[:upper:]')" != "TBD" ]]; then
    status_value="VERIFIED"
    last_updated_value="$existing_last_updated"
  fi

  {
    echo "# Test Matrix"
    echo ""
    echo "## Status"
    echo "- owner-init: \`planner\`"
    echo "- owner-verify: \`tester\`"
    echo "- status: \`$status_value\`"
    echo "- last-updated-utc: $last_updated_value"
    echo "- source-brief-sha: $(hash_or_tbd "$BRIEF_FILE")"
    echo "- source-plan-sha: $(hash_or_tbd "$PLAN_FILE")"
    echo ""
    echo "## Coverage"
    echo "| RQ | Normal | Error | Boundary | Test File | Status |"
    echo "|---|---|---|---|---|---|"
    while IFS=$'\t' read -r rq normal error boundary test_file row_status; do
      [[ -n "$rq" ]] || continue
      printf '| %s | %s | %s | %s | %s | %s |\n' \
        "$rq" \
        "$normal" \
        "$error" \
        "$boundary" \
        "$test_file" \
        "$row_status"
    done < "$new_rows_tmp"
    echo ""
    echo "## Notes"
    echo "- Generated and refreshed by \`scripts/sync-handoffs.sh\` from \`brief.md\`."
    echo "- Planner owns RQ row shape. Tester owns concrete coverage and final \`VERIFIED\` transition."
  } > "$TEST_MATRIX_FILE"
}

if [[ ! -f "$BRIEF_FILE" || ! -f "$PLAN_FILE" ]]; then
  echo "[ERROR] feature packet must include brief.md and plan.md before syncing handoffs" >&2
  exit 1
fi

render_implementer_handoff
render_tester_handoff
render_reviewer_handoff
render_security_handoff
render_test_matrix

echo "[OK] handoffs synced for feature: $FEATURE_ID"
