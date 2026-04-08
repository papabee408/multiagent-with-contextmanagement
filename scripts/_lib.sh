#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT_DIR="$ROOT_DIR/.context"
TASKS_DIR="$ROOT_DIR/docs/tasks"
ACTIVE_TASK_FILE="$CONTEXT_DIR/active_task"

ci_profile_file() {
  printf '%s/docs/context/CI_PROFILE.md' "$ROOT_DIR"
}

task_file() {
  printf '%s/%s.md' "$TASKS_DIR" "$1"
}

task_state_dir() {
  printf '%s/tasks/%s' "$CONTEXT_DIR" "$1"
}

baseline_file() {
  printf '%s/baseline.tsv' "$(task_state_dir "$1")"
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

independent_review_receipt_file() {
  printf '%s/independent-review.receipt' "$(task_state_dir "$1")"
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

resolve_task_id_or_exit() {
  local task_id="${1:-}"

  if [[ -z "$task_id" ]]; then
    task_id="$(active_task_value)"
  fi

  if [[ -z "$task_id" ]]; then
    echo "[ERROR] task-id is required. Set .context/active_task or pass a task id." >&2
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
    trivial) printf '%s' "quick" ;;
    standard) printf '%s' "standard" ;;
    high-risk) printf '%s' "deep" ;;
    *) printf '%s' "unknown" ;;
  esac
}

verification_commands_from_task() {
  section_backtick_values "$(task_file "$1")" "## Verification Commands"
}

base_branch_from_task() {
  section_key_value "$(task_file "$1")" "## Git / PR" "base-branch"
}

branch_strategy_from_task() {
  lower "$(section_key_value "$(task_file "$1")" "## Git / PR" "branch-strategy")"
}

task_branch_pattern() {
  section_key_value "$(ci_profile_file)" "## Git / PR Policy" "task-branch-pattern"
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

merge_method_from_ci_profile() {
  section_key_value "$(ci_profile_file)" "## Git / PR Policy" "merge-method"
}

ci_profile_commands() {
  section_backtick_values "$(ci_profile_file)" "$1"
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
      if (path != "") print path
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
  local head_sha=""

  ensure_runtime_dirs "$task_id"
  : > "$(baseline_file "$task_id")"
  if git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
    head_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  fi
  printf '%s\n' "$head_sha" > "$(bootstrap_head_file "$task_id")"

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    printf '%s\t%s\n' "$relative_path" "$(path_digest "$relative_path")" >> "$(baseline_file "$task_id")"
  done < <(git_changed_files)
}

bootstrap_head_sha() {
  local task_id="$1"

  if [[ -f "$(bootstrap_head_file "$task_id")" ]]; then
    cat "$(bootstrap_head_file "$task_id")"
    return 0
  fi

  printf '%s' ""
}

baseline_digest_for_path() {
  local task_id="$1"
  local target_path="$2"

  if [[ ! -f "$(baseline_file "$task_id")" ]]; then
    printf '%s' ""
    return 0
  fi

  awk -F'\t' -v target="$target_path" '$1 == target { print $2; exit }' "$(baseline_file "$task_id")"
}

effective_changed_files() {
  local task_id="$1"
  local relative_path
  local baseline_digest
  local current_digest
  local bootstrap_head

  bootstrap_head="$(bootstrap_head_sha "$task_id")"

  {
    if [[ -n "$bootstrap_head" ]] && git -C "$ROOT_DIR" rev-parse "$bootstrap_head" >/dev/null 2>&1; then
      git -C "$ROOT_DIR" diff --name-only "$bootstrap_head...HEAD" 2>/dev/null || true
    fi

    git -C "$ROOT_DIR" diff --name-only --cached 2>/dev/null || true
    git -C "$ROOT_DIR" diff --name-only 2>/dev/null || true
    git -C "$ROOT_DIR" ls-files --others --exclude-standard 2>/dev/null || true

    if [[ -f "$(baseline_file "$task_id")" ]]; then
      awk -F'\t' 'NF > 0 { print $1 }' "$(baseline_file "$task_id")"
    fi
  } | sed '/^$/d' | sort -u | while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    current_digest="$(path_digest "$relative_path")"
    baseline_digest="$(baseline_digest_for_path "$task_id" "$relative_path")"
    if [[ -n "$baseline_digest" && "$baseline_digest" == "$current_digest" ]]; then
      continue
    fi
    printf '%s\n' "$relative_path"
  done
}

is_workflow_internal_file() {
  local task_id="$1"
  local relative_path="$2"

  case "$relative_path" in
    "docs/tasks/$task_id.md"|\
    "docs/context/CURRENT.md"|\
    ".context/active_task"|\
    ".context/tasks/$task_id/"*|\
    "docs/context/DECISIONS.md")
      return 0
      ;;
  esac

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

touch_task_updated_at() {
  replace_key_value_or_exit "$(task_file "$1")" "## Status" "updated-at-utc" "$(utc_now)"
}

ensure_clean_worktree() {
  git -C "$ROOT_DIR" diff --quiet --ignore-submodules -- . ':(exclude)docs/context/CURRENT.md' || return 1
  git -C "$ROOT_DIR" diff --cached --quiet --ignore-submodules -- . ':(exclude)docs/context/CURRENT.md' || return 1
  [[ -z "$(git -C "$ROOT_DIR" ls-files --others --exclude-standard | grep -vx 'docs/context/CURRENT.md' || true)" ]] || return 1
}

restore_current_snapshot_file() {
  local current_file="docs/context/CURRENT.md"

  if git -C "$ROOT_DIR" diff --quiet --ignore-submodules -- "$current_file" &&
    git -C "$ROOT_DIR" diff --cached --quiet --ignore-submodules -- "$current_file"; then
    return 0
  fi

  git -C "$ROOT_DIR" restore --staged --worktree --source=HEAD -- "$current_file" >/dev/null 2>&1 ||
    git -C "$ROOT_DIR" restore --worktree --source=HEAD -- "$current_file" >/dev/null 2>&1 ||
    true
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

  base="$(base_branch_from_task "$task_id")"
  strategy="$(branch_strategy_from_task "$task_id")"
  current="$(current_branch_name)"
  read -r behind ahead < <(ahead_behind_against_origin_base "$base")

  if [[ "$current" == "$base" && "$strategy" == "publish-late" && "$ahead" -gt 0 ]]; then
    echo "[FAIL] publish-late"
    echo " - local commits on base branch are not allowed"
    exit 1
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
  awk -F': ' '/^Task-ID:/{print $2; exit}'
}

extract_base_branch_from_text() {
  awk -F': ' '/^Base-Branch:/{print $2; exit}'
}

resolve_pr_number_for_head_branch() {
  local head_branch="$1"
  gh pr view "$head_branch" --json number --jq '.number' 2>/dev/null || true
}

pr_state_value() {
  local task_id="$1"
  local key="$2"
  receipt_value "$(pr_state_file "$task_id")" "$key"
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
