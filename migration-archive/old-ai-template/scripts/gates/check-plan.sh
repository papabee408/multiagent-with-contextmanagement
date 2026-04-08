#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh" "${1:-}"

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

plan_mapping_rq_ids() {
  awk '
    /^## RQ -> Task Mapping/ { in_map = 1; next }
    /^## / && in_map { in_map = 0 }
    in_map {
      while (match($0, /`RQ-[0-9]+`/)) {
        value = substr($0, RSTART + 1, RLENGTH - 2)
        print value
        $0 = substr($0, RSTART + RLENGTH)
      }
    }
  ' "$PLAN_FILE" | sed '/^$/d' | sort -u
}

task_card_field_count() {
  local field="$1"

  awk -v field="$field" '
    /^## Task Cards/ { in_cards = 1; next }
    /^## / && in_cards { in_cards = 0 }
    in_cards && /^### / { in_task = 1; waiting_for_nested = 0; next }
    in_cards && in_task {
      prefix = "- " field ":"
      if (index($0, prefix) == 1) {
        line = substr($0, length(prefix) + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "") {
          count++
          waiting_for_nested = 0
        } else {
          waiting_for_nested = 1
        }
        next
      }

      if (waiting_for_nested) {
        if ($0 ~ /^[[:space:]]*-[[:space:]]*[^[:space:]]/ || $0 ~ /^[[:space:]]+[^[:space:]-]/) {
          count++
          waiting_for_nested = 0
          next
        }
        if ($0 ~ /^### / || $0 ~ /^- [[:alnum:]][[:alnum:] _-]*:/) {
          waiting_for_nested = 0
        }
      }
    }
    END { print count + 0 }
  ' "$PLAN_FILE"
}

failures=()

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "[FAIL] plan: missing plan file ($PLAN_FILE)"
  exit 1
fi

allowed_tmp="$(mktemp)"
brief_rq_tmp="$(mktemp)"
plan_rq_tmp="$(mktemp)"
trap 'rm -f "$allowed_tmp" "$brief_rq_tmp" "$plan_rq_tmp"' EXIT

allowed_files_from_plan > "$allowed_tmp"
brief_rq_ids > "$brief_rq_tmp"
plan_mapping_rq_ids > "$plan_rq_tmp"

if [[ ! -s "$allowed_tmp" ]]; then
  failures+=("missing-target-files")
fi

if [[ ! -s "$plan_rq_tmp" ]]; then
  failures+=("missing-rq-task-mapping")
fi

while IFS= read -r rq; do
  [[ -n "$rq" ]] || continue
  if ! grep -Fxq "$rq" "$plan_rq_tmp"; then
    failures+=("missing-task-mapping($rq)")
  fi

  mapping_line="$(awk -v rq="$rq" '
    /^## RQ -> Task Mapping/ { in_map = 1; next }
    /^## / && in_map { in_map = 0 }
    in_map && index($0, "`" rq "`") {
      print $0
      exit
    }
  ' "$PLAN_FILE")"

  task_name="$(printf '%s' "$mapping_line" | sed -E 's/^.*->[[:space:]]*//')"
  if is_placeholder_text "$task_name"; then
    failures+=("$rq:missing-task-name")
  fi
done < "$brief_rq_tmp"

for key in \
  "target layer / owning module" \
  "dependency constraints / forbidden imports" \
  "shared logic or component placement"; do
  value="$(plan_section_value "## Architecture Notes" "$key")"
  if is_placeholder_text "$value"; then
    failures+=("architecture-notes:missing-${key// /-}")
  fi
done

for key in \
  "existing abstractions to reuse" \
  "extraction candidates for shared component/helper/module" \
  "constants/config/env to centralize" \
  "hardcoded values explicitly allowed"; do
  value="$(plan_section_value "## Reuse and Config Plan" "$key")"
  if is_placeholder_text "$value"; then
    failures+=("reuse-config-plan:missing-${key// /-}")
  fi
done

implementer_mode="$(implementer_mode_from_plan)"
case "$implementer_mode" in
  serial|parallel)
    ;;
  *)
    failures+=("execution-strategy:invalid-implementer-mode($implementer_mode)")
    ;;
esac

merge_owner="$(implementer_merge_owner_from_plan)"
if is_placeholder_text "$merge_owner"; then
  failures+=("execution-strategy:missing-merge-owner")
fi

if ! grep -Eq '^### Task ' "$PLAN_FILE"; then
  failures+=("missing-task-cards")
fi

for field in files change "done when"; do
  count="$(task_card_field_count "$field")"
  if [[ "$count" == "0" ]]; then
    failures+=("task-cards:missing-${field// /-}")
  fi
done

if [[ "$implementer_mode" == "parallel" ]]; then
  parallel_output="$("$ROOT_DIR/scripts/implementer-subtasks.sh" validate --feature "$FEATURE_ID" 2>&1 || true)"
  if [[ "$parallel_output" == *"[FAIL]"* ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      if [[ "$line" == "[FAIL] implementer-subtasks" ]]; then
        continue
      fi
      line="${line# - }"
      failures+=("parallel-subtasks:$line")
    done <<< "$parallel_output"
  fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "[FAIL] plan"
  printf ' - %s\n' "${failures[@]}"
  exit 1
fi

echo "[PASS] plan"
