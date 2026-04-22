#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT_DIR="$ROOT_DIR/.context"
TASKS_DIR="$ROOT_DIR/docs/tasks"

ci_profile_file() {
  printf '%s/docs/context/CI_PROFILE.md' "$ROOT_DIR"
}

task_file() {
  printf '%s/%s.md' "$TASKS_DIR" "$1"
}

task_id_is_valid() {
  local task_id="$1"

  [[ "$task_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

task_state_dir() {
  printf '%s/tasks/%s' "$CONTEXT_DIR" "$1"
}

bootstrap_head_file() {
  printf '%s/bootstrap-head.txt' "$(task_state_dir "$1")"
}

verification_receipt_file() {
  printf '%s/verification.receipt' "$(task_state_dir "$1")"
}

scope_review_receipt_file() {
  printf '%s/scope-review.receipt' "$(task_state_dir "$1")"
}

quality_review_receipt_file() {
  printf '%s/quality-review.receipt' "$(task_state_dir "$1")"
}

verification_log_file() {
  printf '%s/verification.log' "$(task_state_dir "$1")"
}

pr_state_file() {
  printf '%s/pr.env' "$(task_state_dir "$1")"
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

ensure_runtime_dirs() {
  mkdir -p "$CONTEXT_DIR" "$CONTEXT_DIR/tasks" "$(task_state_dir "$1")"
}

branch_task_value() {
  local branch_ref=""
  local task_id=""

  branch_ref="$(current_branch_name 2>/dev/null || true)"
  if [[ -z "$branch_ref" ]]; then
    printf '%s' ""
    return 0
  fi

  task_id="$(task_id_from_branch_ref "$branch_ref" 2>/dev/null || true)"
  task_id="$(trim "$task_id")"
  if [[ -n "$task_id" ]] && task_exists "$task_id"; then
    printf '%s' "$task_id"
    return 0
  fi

  printf '%s' ""
}

resolve_task_id_or_exit() {
  local task_id="${1:-}"

  if [[ -z "$task_id" ]]; then
    task_id="$(branch_task_value)"
  fi

  if [[ -z "$task_id" ]]; then
    echo "[ERROR] task-id is required. Pass a task id or run the command from the task branch." >&2
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

verification_commands_from_task() {
  section_backtick_values "$(task_file "$1")" "## Verification Commands"
}

ci_profile_git_pr_key() {
  section_key_value "$(ci_profile_file)" "## Git / PR Policy" "$1"
}

default_base_branch() {
  local value

  value="$(trim "$(ci_profile_git_pr_key "default-base-branch")")"
  if placeholder_like "$value"; then
    printf '%s' "main"
    return 0
  fi

  printf '%s' "$value"
}

base_branch_from_task() {
  local value

  value="$(trim "$(section_key_value "$(task_file "$1")" "## Git / PR" "base-branch")")"
  if placeholder_like "$value"; then
    default_base_branch
    return 0
  fi

  printf '%s' "$value"
}

branch_strategy_from_task() {
  local value

  value="$(lower "$(trim "$(section_key_value "$(task_file "$1")" "## Git / PR" "branch-strategy")")")"
  if ! placeholder_like "$value"; then
    printf '%s' "$value"
    return 0
  fi

  value="$(lower "$(trim "$(ci_profile_git_pr_key "default-branch-strategy")")")"
  case "$value" in
    publish-late|early-branch)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' "publish-late"
      ;;
  esac
}

task_branch_pattern() {
  ci_profile_git_pr_key "task-branch-pattern"
}

task_branch_name() {
  local task_id="$1"
  local pattern

  pattern="$(task_branch_pattern)"
  if [[ -z "$pattern" ]]; then
    pattern="task/<task-id>"
  fi

  printf '%s' "${pattern//<task-id>/$task_id}"
}

task_exists() {
  local task_id="$1"

  task_id_is_valid "$task_id" && [[ -f "$(task_file "$task_id")" ]]
}

task_is_superseded_by_task() {
  local source_task_id="$1"
  local replacement_task_id="$2"
  local source_file
  local follow_up

  source_file="$(task_file "$source_task_id")"
  [[ -f "$source_file" ]] || return 1
  [[ "$(task_state "$source_task_id")" == "superseded" ]] || return 1

  follow_up="$(section_key_value "$source_file" "## Completion" "follow-up")"

  [[ "$follow_up" == *"docs/tasks/$replacement_task_id.md"* ]] && return 0

  return 1
}

task_id_from_branch_ref() {
  local ref="$1"
  local pattern
  local prefix
  local suffix
  local task_id

  pattern="$(task_branch_pattern)"
  if [[ -z "$ref" || -z "$pattern" || "$pattern" != *"<task-id>"* ]]; then
    printf '%s' ""
    return 1
  fi

  prefix="${pattern%%<task-id>*}"
  suffix="${pattern#*<task-id>}"

  [[ "$ref" == "$prefix"* ]] || {
    printf '%s' ""
    return 1
  }

  if [[ -n "$suffix" && "$ref" != *"$suffix" ]]; then
    printf '%s' ""
    return 1
  fi

  task_id="${ref#"$prefix"}"
  if [[ -n "$suffix" ]]; then
    task_id="${task_id%"$suffix"}"
  fi

  if [[ -z "$task_id" ]]; then
    printf '%s' ""
    return 2
  fi

  if ! task_id_is_valid "$task_id"; then
    printf '%s' ""
    return 2
  fi

  printf '%s' "$task_id"
}

ci_profile_commands() {
  section_backtick_values "$(ci_profile_file)" "$1"
}

git_ref_exists() {
  git -C "$ROOT_DIR" rev-parse --verify "${1}^{commit}" >/dev/null 2>&1
}

diff_names_between() {
  local base_ref="$1"
  local head_ref="$2"

  git -C "$ROOT_DIR" diff --name-only "$base_ref...$head_ref" 2>/dev/null || true
}

committed_changed_files() {
  {
    if [[ -n "${CI_DIFF_BASE:-}" && -n "${CI_DIFF_HEAD:-}" ]] &&
      git_ref_exists "$CI_DIFF_BASE" &&
      git_ref_exists "$CI_DIFF_HEAD"; then
      diff_names_between "$CI_DIFF_BASE" "$CI_DIFF_HEAD"
    elif git_ref_exists "HEAD~1"; then
      diff_names_between "HEAD~1" "HEAD"
    else
      true
    fi
  } | sed '/^$/d' | sort -u
}

task_committed_changed_files() {
  local task_id="$1"
  local base_branch
  local bootstrap_head

  base_branch="$(base_branch_from_task "$task_id")"
  bootstrap_head="$(bootstrap_head_sha "$task_id")"

  {
    if [[ -n "${CI_DIFF_BASE:-}" && -n "${CI_DIFF_HEAD:-}" ]] &&
      git_ref_exists "$CI_DIFF_BASE" &&
      git_ref_exists "$CI_DIFF_HEAD"; then
      diff_names_between "$CI_DIFF_BASE" "$CI_DIFF_HEAD"
    elif [[ -n "$bootstrap_head" ]] && git_ref_exists "$bootstrap_head"; then
      diff_names_between "$bootstrap_head" "HEAD"
    elif [[ -n "$base_branch" ]] && git_ref_exists "origin/$base_branch"; then
      diff_names_between "origin/$base_branch" "HEAD"
    elif [[ -n "$base_branch" ]] && git_ref_exists "$base_branch"; then
      diff_names_between "$base_branch" "HEAD"
    else
      true
    fi
  } | sed '/^$/d' | sort -u
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

path_is_deleted() {
  [[ ! -e "$ROOT_DIR/$1" ]]
}

effective_changed_files() {
  local task_id="$1"
  local relative_path

  {
    task_committed_changed_files "$task_id"
    git -C "$ROOT_DIR" diff --name-only --cached 2>/dev/null || true
    git -C "$ROOT_DIR" diff --name-only 2>/dev/null || true
    git -C "$ROOT_DIR" ls-files --others --exclude-standard 2>/dev/null || true
  } | sed '/^$/d' | sort -u | while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    printf '%s\n' "$relative_path"
  done
}

target_rule_matches_path() {
  local rule="$1"
  local relative_path="$2"
  local pattern=""

  if [[ "$rule" == delete-only:* ]]; then
    pattern="${rule#delete-only:}"
    [[ -n "$pattern" ]] || return 1
    path_is_deleted "$relative_path" || return 1
    [[ "$relative_path" == $pattern ]]
    return $?
  fi

  if [[ "$rule" == */ ]]; then
    [[ "$relative_path" == "$rule"* ]]
    return $?
  fi

  [[ "$relative_path" == "$rule" ]]
}

is_workflow_internal_file() {
  local task_id="$1"
  local relative_path="$2"
  local related_task_id=""

  case "$relative_path" in
    "docs/tasks/$task_id.md"|\
    ".context/active_task"|\
    ".context/tasks/$task_id/"*|\
    "docs/context/DECISIONS.md")
      return 0
      ;;
  esac

  case "$relative_path" in
    docs/tasks/*.md)
      related_task_id="$(basename "$relative_path" .md)"
      if [[ "$related_task_id" != "$task_id" ]] && task_is_superseded_by_task "$related_task_id" "$task_id"; then
        return 0
      fi
      ;;
  esac

  return 1
}

path_allowed_by_task() {
  local task_id="$1"
  local relative_path="$2"
  local rule

  while IFS= read -r rule; do
    [[ -n "$rule" ]] || continue
    if target_rule_matches_path "$rule" "$relative_path"; then
      return 0
    fi
  done < <(target_files_from_task "$task_id")

  return 1
}

non_internal_changed_files() {
  local task_id="$1"
  local relative_path

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    if is_workflow_internal_file "$task_id" "$relative_path"; then
      continue
    fi
    printf '%s\n' "$relative_path"
  done < <(effective_changed_files "$task_id")
}

task_committed_changed_files_for_fingerprint() {
  local task_id="$1"
  local base_branch
  local bootstrap_head

  base_branch="$(base_branch_from_task "$task_id")"
  bootstrap_head="$(bootstrap_head_sha "$task_id")"

  {
    if [[ -n "$bootstrap_head" ]] && git_ref_exists "$bootstrap_head"; then
      diff_names_between "$bootstrap_head" "HEAD"
    elif [[ -n "$base_branch" ]] && git_ref_exists "$base_branch"; then
      diff_names_between "$base_branch" "HEAD"
    else
      committed_changed_files
    fi
  } | sed '/^$/d' | sort -u
}

task_fingerprint_changed_files() {
  local task_id="$1"
  local relative_path

  {
    task_committed_changed_files_for_fingerprint "$task_id"
    git -C "$ROOT_DIR" diff --name-only --cached 2>/dev/null || true
    git -C "$ROOT_DIR" diff --name-only 2>/dev/null || true
    git -C "$ROOT_DIR" ls-files --others --exclude-standard 2>/dev/null || true
  } | sed '/^$/d' | sort -u | while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    printf '%s\n' "$relative_path"
  done
}

task_contract_fingerprint_material() {
  local task_id="$1"
  local file

  file="$(task_file "$task_id")"

  {
    echo "risk-level=$(task_risk_level "$task_id")"
    echo "intake"
    section_bullet_values "$file" "## Intake"
    echo "goal"
    section_bullet_values "$file" "## Goal"
    echo "non-goals"
    section_bullet_values "$file" "## Non-goals"
    echo "requirements"
    section_bullet_values "$file" "## Requirements"
    echo "implementation-plan"
    section_bullet_values "$file" "## Implementation Plan"
    echo "target-files"
    target_files_from_task "$task_id"
    echo "out-of-scope"
    section_bullet_values "$file" "## Out of Scope"
    echo "scope-guardrails"
    section_bullet_values "$file" "## Scope Guardrails"
    echo "reuse-and-constraints"
    section_bullet_values "$file" "## Reuse And Constraints"
    echo "risk-controls"
    section_bullet_values "$file" "## Risk Controls"
    echo "acceptance"
    section_bullet_values "$file" "## Acceptance"
    echo "verification-commands"
    verification_commands_from_task "$task_id"
    echo "git-pr"
    section_bullet_values "$file" "## Git / PR"
  }
}

task_fingerprint() {
  local task_id="$1"
  local has_files=0
  local relative_path

  {
    echo "task-id=$task_id"
    echo "task-contract"
    task_contract_fingerprint_material "$task_id"
    echo "changed-files"
    while IFS= read -r relative_path; do
      [[ -n "$relative_path" ]] || continue
      if is_workflow_internal_file "$task_id" "$relative_path"; then
        continue
      fi
      has_files=1
      printf '%s\t%s\n' "$relative_path" "$(path_digest "$relative_path")"
    done < <(task_fingerprint_changed_files "$task_id")
    if [[ "$has_files" == "0" ]]; then
      echo "__empty__"
    fi
  } | sha256_stdin
}

phase_status_value() {
  local task_id="$1"
  local label="$2"

  case "$label" in
    verification)
      section_key_value "$(task_file "$task_id")" "## Verification Status" "verification-status"
      ;;
    scope-review)
      section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-status"
      ;;
    quality-review)
      section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-status"
      ;;
    *)
      printf '%s' ""
      return 1
      ;;
  esac
}

phase_fingerprint_value() {
  local task_id="$1"
  local label="$2"

  case "$label" in
    verification)
      section_key_value "$(task_file "$task_id")" "## Verification Status" "verification-fingerprint"
      ;;
    scope-review)
      section_key_value "$(task_file "$task_id")" "## Review Status" "scope-review-fingerprint"
      ;;
    quality-review)
      section_key_value "$(task_file "$task_id")" "## Review Status" "quality-review-fingerprint"
      ;;
    *)
      printf '%s' ""
      return 1
      ;;
  esac
}

phase_receipt_file() {
  local task_id="$1"
  local label="$2"

  case "$label" in
    verification)
      verification_receipt_file "$task_id"
      ;;
    scope-review)
      scope_review_receipt_file "$task_id"
      ;;
    quality-review)
      quality_review_receipt_file "$task_id"
      ;;
    *)
      printf '%s' ""
      return 1
      ;;
  esac
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

write_runtime_receipt() {
  local file="$1"
  local result="$2"
  local fingerprint="$3"
  local summary="$4"

  {
    echo "result=$result"
    echo "executed_at_utc=$(utc_now)"
    echo "fingerprint=$fingerprint"
    echo "summary=$summary"
  } > "$file"
}

ensure_runtime_receipt_pass_and_fresh() {
  local task_id="$1"
  local receipt_file="$2"
  local label="$3"
  local current_fingerprint
  local receipt_result
  local receipt_fingerprint

  if [[ ! -f "$receipt_file" ]]; then
    echo "[FAIL] $label"
    echo " - missing runtime receipt for task: $task_id"
    exit 1
  fi

  current_fingerprint="$(task_fingerprint "$task_id")"
  receipt_result="$(receipt_value "$receipt_file" "result")"
  receipt_fingerprint="$(receipt_value "$receipt_file" "fingerprint")"

  if [[ "$receipt_result" != "PASS" ]]; then
    echo "[FAIL] $label"
    echo " - last runtime receipt is not PASS for task: $task_id"
    exit 1
  fi

  if [[ "$receipt_fingerprint" != "$current_fingerprint" ]]; then
    echo "[FAIL] $label"
    echo " - runtime receipt is stale for task: $task_id"
    exit 1
  fi
}

ensure_task_phase_pass_and_fresh() {
  local task_id="$1"
  local label="$2"
  local tracked_status
  local tracked_fingerprint
  local current_fingerprint
  local receipt_file

  tracked_fingerprint="$(trim "$(phase_fingerprint_value "$task_id" "$label" 2>/dev/null || true)")"
  if ! placeholder_like "$tracked_fingerprint"; then
    tracked_status="$(lower "$(trim "$(phase_status_value "$task_id" "$label" 2>/dev/null || true)")")"
    current_fingerprint="$(task_fingerprint "$task_id")"

    if [[ "$tracked_status" != "pass" ]]; then
      echo "[FAIL] $label"
      echo " - tracked freshness requires status=pass for task: $task_id"
      exit 1
    fi

    if [[ "$tracked_fingerprint" != "$current_fingerprint" ]]; then
      echo "[FAIL] $label"
      echo " - tracked freshness is stale for task: $task_id"
      exit 1
    fi

    return 0
  fi

  receipt_file="$(phase_receipt_file "$task_id" "$label")"
  ensure_runtime_receipt_pass_and_fresh "$task_id" "$receipt_file" "$label"
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

section_has_key() {
  local file="$1"
  local section="$2"
  local key="$3"

  awk -v section="$section" -v key="$key" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section {
      prefix = "- " key ":"
      if (index($0, prefix) == 1) {
        found = 1
        exit
      }
    }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

upsert_key_value_or_exit() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local tmp_file

  if section_has_key "$file" "$section" "$key"; then
    replace_key_value_or_exit "$file" "$section" "$key" "$value"
    return 0
  fi

  tmp_file="$(mktemp)"
  awk -v section="$section" -v key="$key" -v value="$value" '
    $0 == section {
      print
      in_section = 1
      found_section = 1
      next
    }
    in_section && /^## / {
      print "- " key ": " value
      inserted = 1
      in_section = 0
    }
    { print }
    END {
      if (!found_section) exit 7
      if (in_section && !inserted) {
        print "- " key ": " value
      }
    }
  ' "$file" > "$tmp_file" || {
    rm -f "$tmp_file"
    echo "[ERROR] missing section '$section' ($file)" >&2
    exit 1
  }

  mv "$tmp_file" "$file"
}

touch_task_updated_at() {
  replace_key_value_or_exit "$(task_file "$1")" "## Status" "updated-at-utc" "$(utc_now)"
}

mark_task_superseded() {
  local task_id="$1"
  local replacement_task_id="$2"
  local reason="$3"
  local task_path="docs/tasks/$replacement_task_id.md"

  replace_key_value_or_exit "$(task_file "$task_id")" "## Status" "state" "superseded"
  touch_task_updated_at "$task_id"
  replace_key_value_or_exit "$(task_file "$task_id")" "## Completion" "summary" "Task superseded before completion because $reason"
  replace_key_value_or_exit "$(task_file "$task_id")" "## Completion" "follow-up" "Continue in $task_path."
}

capture_bootstrap_head() {
  local task_id="$1"
  local head_sha=""

  ensure_runtime_dirs "$task_id"
  if git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
    head_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  fi

  printf '%s\n' "$head_sha" > "$(bootstrap_head_file "$task_id")"
}

bootstrap_head_sha() {
  local task_id="$1"

  if [[ -f "$(bootstrap_head_file "$task_id")" ]]; then
    cat "$(bootstrap_head_file "$task_id")"
    return 0
  fi

  printf '%s' ""
}

ensure_clean_worktree() {
  git -C "$ROOT_DIR" diff --quiet --ignore-submodules -- . || return 1
  git -C "$ROOT_DIR" diff --cached --quiet --ignore-submodules -- . || return 1
  [[ -z "$(git -C "$ROOT_DIR" ls-files --others --exclude-standard)" ]] || return 1
}

current_branch_name() {
  git -C "$ROOT_DIR" branch --show-current
}

origin_url() {
  git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || true
}

has_origin_remote() {
  [[ -n "$(origin_url)" ]]
}

fetch_origin_base() {
  local base="$1"

  has_origin_remote || return 1
  git -C "$ROOT_DIR" fetch origin "$base" --quiet >/dev/null 2>&1 || return 1
}

origin_base_exists() {
  local base="$1"
  git -C "$ROOT_DIR" rev-parse --verify "origin/$base" >/dev/null 2>&1
}

ensure_origin_base_ref_available() {
  local base="$1"

  has_origin_remote || {
    echo "[FAIL] git-origin"
    echo " - origin remote is required"
    exit 1
  }

  fetch_origin_base "$base" || {
    echo "[FAIL] git-origin"
    echo " - could not fetch origin/$base"
    exit 1
  }

  origin_base_exists "$base" || {
    echo "[FAIL] git-origin"
    echo " - origin/$base does not exist"
    exit 1
  }
}

ahead_behind_against_origin_base() {
  local base="$1"

  if ! has_origin_remote; then
    printf '%s %s\n' "0" "0"
    return 1
  fi

  fetch_origin_base "$base" >/dev/null 2>&1 || true
  if ! origin_base_exists "$base"; then
    printf '%s %s\n' "0" "0"
    return 1
  fi

  git -C "$ROOT_DIR" rev-list --left-right --count "origin/$base...HEAD"
}

ensure_publish_late_base_branch_safe() {
  local task_id="$1"
  local mode="${2:-warn}"
  local base
  local strategy
  local current
  local behind
  local ahead
  local bootstrap_head
  local head_sha

  base="$(base_branch_from_task "$task_id")"
  strategy="$(branch_strategy_from_task "$task_id")"
  current="$(current_branch_name)"
  read -r behind ahead < <(ahead_behind_against_origin_base "$base")

  if [[ "$current" == "$base" && "$strategy" == "publish-late" && "$ahead" -gt 0 ]]; then
    echo "[FAIL] publish-late"
    echo " - local commits on base branch are not allowed"
    exit 1
  fi

  if [[ "$current" == "$base" && "$strategy" == "publish-late" && "$ahead" -eq 0 ]]; then
    bootstrap_head="$(bootstrap_head_sha "$task_id")"
    if [[ -n "$bootstrap_head" ]] && git_ref_exists "$bootstrap_head"; then
      head_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
      if [[ "$head_sha" != "$bootstrap_head" ]]; then
        echo "[FAIL] publish-late"
        echo " - local commits on base branch are not allowed"
        exit 1
      fi
    fi
  fi

  if [[ "$behind" -gt 0 && "$mode" == "fail-on-behind" ]]; then
    echo "[FAIL] base-sync"
    echo " - current branch is behind origin/$base"
    exit 1
  fi

  if [[ "$behind" -gt 0 && "$mode" != "fail-on-behind" ]]; then
    echo "[WARN] current branch is behind origin/$base" >&2
  fi
}

render_pr_metadata_block() {
  local task_id="$1"
  local base="$2"

  cat <<EOF
<!-- task-metadata:start -->
Task-ID: $task_id
Task-File: docs/tasks/$task_id.md
Base-Branch: $base
<!-- task-metadata:end -->
EOF
}

extract_task_id_from_text() {
  awk '
    /^Task-ID:/ {
      value = $0
      sub(/^Task-ID:[[:space:]]*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value == "") {
        invalid = 1
        next
      }
      count += 1
      if (count == 1) {
        first = value
        next
      }
      invalid = 1
      next
    }
    END {
      if (invalid) {
        exit 2
      }
      if (count == 1) {
        print first
        exit 0
      }
      if (count == 0) {
        exit 1
      }
    }
  '
}

extract_base_branch_from_text() {
  awk -F': ' '/^Base-Branch:/{print $2; exit}'
}

resolve_pr_number_for_head_branch() {
  local head_branch="$1"
  gh pr view "$head_branch" --json number --jq '.number' 2>/dev/null || true
}

pr_cache_value() {
  local task_id="$1"
  local key="$2"
  receipt_value "$(pr_state_file "$task_id")" "$key"
}

resolve_pr_snapshot_for_task() {
  local task_id="$1"
  local current_branch="${2:-}"
  local task_branch=""
  local cached_status=""
  local cached_number=""
  local cached_url=""
  local cached_branch=""
  local lookup_branch=""
  local pr_json=""
  local pr_status=""
  local seen="|"

  cached_status="$(pr_cache_value "$task_id" "pr_status")"
  cached_number="$(pr_cache_value "$task_id" "pr_number")"
  cached_url="$(pr_cache_value "$task_id" "pr_url")"
  cached_branch="$(pr_cache_value "$task_id" "published_branch")"
  task_branch="$(task_branch_name "$task_id")"

  if command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    for lookup_branch in "$task_branch" "$cached_branch"; do
      [[ -n "$lookup_branch" && "$lookup_branch" != "none" ]] || continue
      [[ "$seen" == *"|$lookup_branch|"* ]] && continue
      seen="${seen}${lookup_branch}|"

      pr_json="$(gh pr view "$lookup_branch" --json number,url,isDraft,state 2>/dev/null || true)"
      [[ -n "$pr_json" ]] || continue

      if [[ "$(printf '%s' "$pr_json" | jq -r '.isDraft // false')" == "true" ]]; then
        pr_status="draft"
      else
        case "$(printf '%s' "$pr_json" | jq -r '.state // "OPEN"')" in
          OPEN)
            pr_status="open"
            ;;
          MERGED)
            pr_status="merged"
            ;;
          CLOSED)
            pr_status="closed"
            ;;
          *)
            pr_status="none"
            ;;
        esac
      fi

      printf '%s\n%s\n%s\n' \
        "${pr_status:-none}" \
        "$(printf '%s' "$pr_json" | jq -r '.number // "none"')" \
        "$(printf '%s' "$pr_json" | jq -r '.url // "none"')"
      return 0
    done

    if [[ -n "$cached_number" ]]; then
      pr_json="$(gh pr view "$cached_number" --json number,url,isDraft,state 2>/dev/null || true)"
      if [[ -n "$pr_json" ]]; then
        if [[ "$(printf '%s' "$pr_json" | jq -r '.isDraft // false')" == "true" ]]; then
          pr_status="draft"
        else
          case "$(printf '%s' "$pr_json" | jq -r '.state // "OPEN"')" in
            OPEN)
              pr_status="open"
              ;;
            MERGED)
              pr_status="merged"
              ;;
            CLOSED)
              pr_status="closed"
              ;;
            *)
              pr_status="none"
              ;;
          esac
        fi

        printf '%s\n%s\n%s\n' \
          "${pr_status:-none}" \
          "$(printf '%s' "$pr_json" | jq -r '.number // "none"')" \
          "$(printf '%s' "$pr_json" | jq -r '.url // "none"')"
        return 0
      fi
    fi
  fi

  if [[ -n "$cached_status" || -n "$cached_number" || -n "$cached_url" ]]; then
    printf '%s\n%s\n%s\n' "${cached_status:-none}" "${cached_number:-none}" "${cached_url:-none}"
    return 0
  fi

  printf 'none\nnone\nnone\n'
}

pr_state_value() {
  local task_id="$1"
  local key="$2"
  local snapshot

  snapshot="$(resolve_pr_snapshot_for_task "$task_id")"
  case "$key" in
    pr_status)
      printf '%s' "$(printf '%s\n' "$snapshot" | sed -n '1p')"
      ;;
    pr_number)
      printf '%s' "$(printf '%s\n' "$snapshot" | sed -n '2p')"
      ;;
    pr_url)
      printf '%s' "$(printf '%s\n' "$snapshot" | sed -n '3p')"
      ;;
    *)
      pr_cache_value "$task_id" "$key"
      ;;
  esac
}

parse_github_owner_repo_from_origin() {
  local remote_url
  local owner=""
  local repo=""

  remote_url="$(origin_url)"

  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  fi

  printf '%s\n%s\n' "$owner" "$repo"
}

github_api_repo_path() {
  local owner=""
  local repo=""
  local line

  if [[ -n "${GITHUB_REPO_PATH_OVERRIDE:-}" ]]; then
    printf '%s' "$GITHUB_REPO_PATH_OVERRIDE"
    return 0
  fi

  while IFS= read -r line; do
    if [[ -z "$owner" ]]; then
      owner="$line"
    elif [[ -z "$repo" ]]; then
      repo="$line"
    fi
  done < <(parse_github_owner_repo_from_origin)

  if [[ -z "$owner" || -z "$repo" ]]; then
    echo "[FAIL] github-origin"
    echo " - could not parse owner/repo from origin remote"
    exit 1
  fi

  printf 'repos/%s/%s' "$owner" "$repo"
}

required_checks_from_branch_protection() {
  local base="$1"
  local repo_path

  repo_path="$(github_api_repo_path)"
  gh api "$repo_path/branches/$base/protection" --jq '.required_status_checks.checks[].context' 2>/dev/null | sed '/^$/d' || true
}

required_checks_fallback_from_ci_profile() {
  section_backtick_values "$(ci_profile_file)" "## Required Check Fallback"
}

resolve_required_checks() {
  local base="$1"
  local raw

  raw="$(required_checks_from_branch_protection "$base" || true)"
  if [[ -n "$raw" ]]; then
    printf '%s\n' "$raw"
    return 0
  fi

  required_checks_fallback_from_ci_profile
}

ensure_done_task_fresh_for_publish() {
  local task_id="$1"

  ensure_task_phase_pass_and_fresh "$task_id" "verification"
  ensure_task_phase_pass_and_fresh "$task_id" "scope-review"
  ensure_task_phase_pass_and_fresh "$task_id" "quality-review"
}

ensure_review_task_fresh_for_publish() {
  local task_id="$1"
  local task_path
  local scope_status
  local quality_status

  task_path="$(task_file "$task_id")"
  ensure_task_phase_pass_and_fresh "$task_id" "verification"

  if ! section_has_key "$task_path" "## Review Status" "scope-review-status"; then
    echo "[FAIL] scope-review"
    echo " - review-stage publish requires scope-review-status to be present"
    exit 1
  fi
  scope_status="$(lower "$(trim "$(phase_status_value "$task_id" "scope-review" 2>/dev/null || true)")")"
  case "$scope_status" in
    pending)
      ;;
    pass)
      ensure_task_phase_pass_and_fresh "$task_id" "scope-review"
      ;;
    fail)
      echo "[FAIL] scope-review"
      echo " - review-stage publish requires scope review to be passing or still pending"
      exit 1
      ;;
    *)
      echo "[FAIL] scope-review"
      echo " - review-stage publish found invalid scope-review-status=$scope_status"
      exit 1
      ;;
  esac

  if ! section_has_key "$task_path" "## Review Status" "quality-review-status"; then
    echo "[FAIL] quality-review"
    echo " - review-stage publish requires quality-review-status to be present"
    exit 1
  fi
  quality_status="$(lower "$(trim "$(phase_status_value "$task_id" "quality-review" 2>/dev/null || true)")")"
  case "$quality_status" in
    pending)
      ;;
    pass)
      ensure_task_phase_pass_and_fresh "$task_id" "quality-review"
      ;;
    fail)
      echo "[FAIL] quality-review"
      echo " - review-stage publish requires quality review to be passing or still pending"
      exit 1
      ;;
    *)
      echo "[FAIL] quality-review"
      echo " - review-stage publish found invalid quality-review-status=$quality_status"
      exit 1
      ;;
  esac
}

ensure_done_task_receipts_fresh_for_publish() {
  ensure_done_task_fresh_for_publish "$1"
}
