#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT_DIR="$ROOT_DIR/.context"
TASKS_DIR="$ROOT_DIR/docs/tasks"
ACTIVE_TASK_FILE="$CONTEXT_DIR/active_task"

tracked_receipts_root() {
  printf '%s/docs/tasks/.receipts' "$ROOT_DIR"
}

ci_profile_file() {
  printf '%s/docs/context/CI_PROFILE.md' "$ROOT_DIR"
}

trim() {
  printf '%s' "${1:-}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

utc_now() {
  date -u +"%Y-%m-%d %H:%M:%SZ"
}

placeholder_like() {
  local value
  value="$(lower "$(trim "${1:-}")")"

  case "$value" in
    ""|"tbd"|"todo"|"pending"|"required"|"replace"|"replace-me"|"fill-me"|"n/a")
      return 0
      ;;
  esac

  if [[ "$value" == *"<replace"* || "$value" == *"replace with a real command"* ]]; then
    return 0
  fi

  return 1
}

tsv_sanitize() {
  local value="${1:-}"
  value="${value//$'\t'/ }"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  printf '%s' "$(trim "$value")"
}

sha256_file() {
  local path="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
    return 0
  fi

  sha256sum "$path" | awk '{print $1}'
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return 0
  fi

  sha256sum | awk '{print $1}'
}

task_file() {
  printf '%s/%s.md' "$TASKS_DIR" "$1"
}

task_state_dir() {
  printf '%s/tasks/%s' "$CONTEXT_DIR" "$1"
}

tracked_receipt_dir() {
  printf '%s/%s' "$(tracked_receipts_root)" "$1"
}

baseline_file() {
  printf '%s/baseline.tsv' "$(task_state_dir "$1")"
}

verification_receipt_file() {
  printf '%s/verification.receipt' "$(task_state_dir "$1")"
}

tracked_verification_receipt_file() {
  printf '%s/verification.receipt' "$(tracked_receipt_dir "$1")"
}

scope_review_receipt_file() {
  printf '%s/scope-review.receipt' "$(task_state_dir "$1")"
}

tracked_scope_review_receipt_file() {
  printf '%s/scope-review.receipt' "$(tracked_receipt_dir "$1")"
}

quality_review_receipt_file() {
  printf '%s/quality-review.receipt' "$(task_state_dir "$1")"
}

tracked_quality_review_receipt_file() {
  printf '%s/quality-review.receipt' "$(tracked_receipt_dir "$1")"
}

independent_review_receipt_file() {
  printf '%s/independent-review.receipt' "$(task_state_dir "$1")"
}

tracked_independent_review_receipt_file() {
  printf '%s/independent-review.receipt' "$(tracked_receipt_dir "$1")"
}

verification_log_file() {
  printf '%s/verification.log' "$(task_state_dir "$1")"
}

ensure_runtime_dirs() {
  mkdir -p "$CONTEXT_DIR" "$CONTEXT_DIR/tasks" "$(task_state_dir "$1")" "$(tracked_receipt_dir "$1")"
}

active_task_value() {
  if [[ -f "$ACTIVE_TASK_FILE" ]]; then
    tr -d ' \n\r\t' < "$ACTIVE_TASK_FILE"
    return 0
  fi

  current_snapshot_active_task_value
}

current_snapshot_active_task_value() {
  local current_file="$ROOT_DIR/docs/context/CURRENT.md"
  local value

  if [[ ! -f "$current_file" ]]; then
    printf '%s' ""
    return 0
  fi

  value="$(awk '
    index($0, "- active-task:") == 1 {
      line = substr($0, length("- active-task:") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$current_file")"
  value="$(trim "$value")"

  if [[ -z "$value" || "$(lower "$value")" == "none" ]]; then
    printf '%s' ""
    return 0
  fi

  printf '%s' "$value"
}

template_health_dir() {
  printf '%s/template-health' "$CONTEXT_DIR"
}

template_metrics_file() {
  printf '%s/task-metrics.tsv' "$(template_health_dir)"
}

template_feedback_file() {
  printf '%s/task-feedback.tsv' "$(template_health_dir)"
}

sync_receipt_to_tracked() {
  local source_file="$1"
  local target_file="$2"

  mkdir -p "$(dirname "$target_file")"
  cp "$source_file" "$target_file"
}

line_count() {
  awk 'NF { count += 1 } END { print count + 0 }'
}

ensure_tsv_header() {
  local file="$1"
  local header="$2"

  mkdir -p "$(dirname "$file")"
  if [[ ! -f "$file" ]]; then
    printf '%s\n' "$header" > "$file"
  fi
}

resolve_task_id_or_exit() {
  local task_id="${1:-}"

  if [[ -z "$task_id" ]]; then
    task_id="$(active_task_value)"
  fi

  if [[ -z "$task_id" ]]; then
    echo "[ERROR] task-id is required. Set .context/active_task, refresh docs/context/CURRENT.md, or pass a task id." >&2
    exit 1
  fi

  printf '%s' "$task_id"
}

section_key_value() {
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
        gsub(/`/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

section_bullet_values() {
  local file="$1"
  local section="$2"

  awk -v section="$section" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section && /^[[:space:]]*-[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
    }
  ' "$file"
}

section_backtick_values() {
  local file="$1"
  local section="$2"

  awk -v section="$section" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section {
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line ~ /^-[[:space:]]*`[^`]+`[[:space:]]*$/) {
        sub(/^-[[:space:]]*`/, "", line)
        sub(/`[[:space:]]*$/, "", line)
        print line
      } else if (line ~ /^`[^`]+`[[:space:]]*$/) {
        sub(/^`/, "", line)
        sub(/`[[:space:]]*$/, "", line)
        print line
      }
    }
  ' "$file" | sed '/^$/d'
}

target_files_from_task() {
  section_backtick_values "$(task_file "$1")" "## Target Files" | sort -u
}

task_state() {
  section_key_value "$(task_file "$1")" "## Status" "state"
}

task_risk_level() {
  lower "$(section_key_value "$(task_file "$1")" "## Status" "risk-level")"
}

task_review_profile() {
  case "$(task_risk_level "$1")" in
    trivial)
      printf '%s' "quick"
      ;;
    standard)
      printf '%s' "standard"
      ;;
    high-risk)
      printf '%s' "deep"
      ;;
    *)
      printf '%s' "unknown"
      ;;
  esac
}

verification_commands_from_task() {
  section_backtick_values "$(task_file "$1")" "## Verification Commands"
}

ci_profile_platform() {
  lower "$(section_key_value "$(ci_profile_file)" "## Project Profile" "platform")"
}

ci_profile_stack() {
  lower "$(section_key_value "$(ci_profile_file)" "## Project Profile" "stack")"
}

ci_profile_package_manager() {
  lower "$(section_key_value "$(ci_profile_file)" "## Project Profile" "package-manager")"
}

ci_profile_commands() {
  section_backtick_values "$(ci_profile_file)" "$1"
}

independent_review_proof_for_fingerprint() {
  local task_id="$1"
  local fingerprint="$2"
  local reviewer="$3"
  local summary="$4"

  {
    echo "independent-review"
    echo "task=$task_id"
    echo "fingerprint=$fingerprint"
    echo "reviewer=$(tsv_sanitize "$reviewer")"
    echo "summary=$(tsv_sanitize "$summary")"
  } | sha256_stdin
}

independent_review_proof() {
  independent_review_proof_for_fingerprint "$1" "$(task_fingerprint "$1")" "$2" "$3"
}

task_contract_fingerprint_material() {
  local file
  file="$(task_file "$1")"

  {
    echo "goal"
    section_bullet_values "$file" "## Goal"
    echo "non-goals"
    section_bullet_values "$file" "## Non-goals"
    echo "requirements"
    section_bullet_values "$file" "## Requirements"
    echo "implementation-plan"
    section_bullet_values "$file" "## Implementation Plan"
    echo "risk-level"
    task_risk_level "$1"
    echo "target-files"
    target_files_from_task "$1"
    echo "out-of-scope"
    section_bullet_values "$file" "## Out of Scope"
    echo "scope-guardrails"
    section_bullet_values "$file" "## Scope Guardrails"
    echo "reuse-and-constraints"
    section_bullet_values "$file" "## Reuse and Constraints"
    echo "risk-controls"
    section_bullet_values "$file" "## Risk Controls"
    echo "acceptance"
    section_bullet_values "$file" "## Acceptance"
    echo "verification-commands"
    verification_commands_from_task "$1"
  }
}

git_changed_files() {
  git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all | awk '
    {
      path = substr($0, 4)
      if (index(path, " -> ") > 0) {
        split(path, parts, " -> ")
        path = parts[length(parts)]
      }
      gsub(/^"/, "", path)
      gsub(/"$/, "", path)
      if (path != "") {
        print path
      }
    }
  ' | sed '/^$/d' | sort -u
}

path_digest() {
  local relative_path="$1"
  local absolute_path="$ROOT_DIR/$relative_path"

  if [[ -f "$absolute_path" ]]; then
    sha256_file "$absolute_path"
    return 0
  fi

  printf '%s' "__missing__"
}

capture_baseline_snapshot() {
  local task_id="$1"
  local baseline_path

  ensure_runtime_dirs "$task_id"
  baseline_path="$(baseline_file "$task_id")"

  : > "$baseline_path"
  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    printf '%s\t%s\n' "$relative_path" "$(path_digest "$relative_path")" >> "$baseline_path"
  done < <(git_changed_files)
}

baseline_digest_for_path() {
  local task_id="$1"
  local target_path="$2"
  local baseline_path

  baseline_path="$(baseline_file "$task_id")"
  if [[ ! -f "$baseline_path" ]]; then
    printf '%s' ""
    return 0
  fi

  awk -F'\t' -v target="$target_path" '$1 == target { print $2; exit }' "$baseline_path"
}

effective_changed_files() {
  local task_id="$1"
  local baseline_digest
  local current_digest

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    current_digest="$(path_digest "$relative_path")"
    baseline_digest="$(baseline_digest_for_path "$task_id" "$relative_path")"
    if [[ -n "$baseline_digest" && "$baseline_digest" == "$current_digest" ]]; then
      continue
    fi
    printf '%s\n' "$relative_path"
  done < <(git_changed_files)
}

is_workflow_internal_file() {
  local task_id="$1"
  local relative_path="$2"

  case "$relative_path" in
    "docs/tasks/$task_id.md"|\
    "docs/tasks/.receipts/$task_id"/*|\
    "docs/context/CURRENT.md"|\
    "docs/context/DECISIONS.md"|\
    ".context/active_task"|\
    ".context/tasks/$task_id"/*)
      return 0
      ;;
  esac

  return 1
}

non_internal_changed_files() {
  local task_id="$1"
  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    if is_workflow_internal_file "$task_id" "$relative_path"; then
      continue
    fi
    printf '%s\n' "$relative_path"
  done < <(effective_changed_files "$task_id")
}

task_fingerprint() {
  local task_id="$1"
  local has_files=0

  {
    echo "task-id=$task_id"
    echo "task-contract"
    task_contract_fingerprint_material "$task_id"
    echo "changed-files"
    while IFS= read -r relative_path; do
      [[ -n "$relative_path" ]] || continue
      has_files=1
      printf '%s\t%s\n' "$relative_path" "$(path_digest "$relative_path")"
    done < <(non_internal_changed_files "$task_id")
    if [[ "$has_files" == "0" ]]; then
      echo "__empty__"
    fi
  } | sha256_stdin
}

receipt_value() {
  local file="$1"
  local key="$2"

  if [[ ! -f "$file" ]]; then
    printf '%s' ""
    return 0
  fi

  awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$file"
}

ensure_task_state_in() {
  local task_id="$1"
  shift

  local current_state
  current_state="$(task_state "$task_id")"

  for allowed_state in "$@"; do
    if [[ "$current_state" == "$allowed_state" ]]; then
      return 0
    fi
  done

  echo "[FAIL] task-state"
  echo " - task=$task_id"
  echo " - current=$current_state"
  echo " - required=$(printf '%s ' "$@" | sed 's/[[:space:]]*$//')"
  exit 1
}

touch_task_updated_at() {
  replace_key_value_or_exit "$(task_file "$1")" "## Status" "updated-at-utc" "$(utc_now)"
}

ensure_receipt_pass_and_fresh() {
  local task_id="$1"
  local receipt_file="$2"
  local label="$3"
  local current_fingerprint
  local receipt_result
  local receipt_fingerprint

  if [[ ! -f "$receipt_file" ]]; then
    echo "[FAIL] $label"
    echo " - missing receipt for task: $task_id"
    exit 1
  fi

  current_fingerprint="$(task_fingerprint "$task_id")"
  receipt_result="$(receipt_value "$receipt_file" "result")"
  receipt_fingerprint="$(receipt_value "$receipt_file" "fingerprint")"

  if [[ "$receipt_result" != "PASS" ]]; then
    echo "[FAIL] $label"
    echo " - last receipt result is not PASS for task: $task_id"
    exit 1
  fi

  if [[ "$receipt_fingerprint" != "$current_fingerprint" ]]; then
    echo "[FAIL] $label"
    echo " - receipt is stale for task: $task_id"
    exit 1
  fi
}

replace_key_value_or_exit() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local tmp_file

  tmp_file="$(mktemp)"
  awk -v section="$section" -v key="$key" -v value="$value" '
    $0 == section { in_section = 1 }
    /^## / && in_section && $0 != section { in_section = 0 }
    in_section {
      prefix = "- " key ":"
      if (index($0, prefix) == 1) {
        print prefix " " value
        replaced = 1
        next
      }
    }
    { print }
    END {
      if (!replaced) exit 7
    }
  ' "$file" > "$tmp_file" || {
    rm -f "$tmp_file"
    echo "[ERROR] missing field '$key' in section '$section' ($file)" >&2
    exit 1
  }

  mv "$tmp_file" "$file"
}
