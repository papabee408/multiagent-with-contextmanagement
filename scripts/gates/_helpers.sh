#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/_git_change_helpers.sh"
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

brief_rq_ids() {
  local brief_file="$FEATURE_DIR/brief.md"

  if [[ ! -f "$brief_file" ]]; then
    return 0
  fi

  awk '
    /^## Requirements \(RQ\)/ { in_rq = 1; next }
    /^## / && in_rq { in_rq = 0 }
    in_rq {
      while (match($0, /`RQ-[0-9]+`/)) {
        value = substr($0, RSTART + 1, RLENGTH - 2)
        print value
        $0 = substr($0, RSTART + RLENGTH)
      }
    }
  ' "$brief_file" | sed '/^$/d' | sort -u
}

section_key_value() {
  local file="$1"
  local section="$2"
  local key="$3"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

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

normalize_mode_token() {
  local value="${1:-}"
  value="$(lower "$(trim "$value")")"
  case "$value" in
    single|multi-agent|trivial|lite|full|serial|parallel)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

normalize_risk_class_token() {
  local value="${1:-}"
  value="$(lower "$(trim "$value")")"
  case "$value" in
    trivial|standard|high-risk)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

risk_signal_keys() {
  printf '%s\n' \
    "auth-permissions" \
    "payments-billing" \
    "data-migration" \
    "public-api" \
    "infra-deploy" \
    "secrets-sensitive-data" \
    "blast-radius"
}

normalize_yes_no_token() {
  local value="${1:-}"
  value="$(lower "$(trim "$value")")"
  case "$value" in
    yes|y|true)
      printf '%s' "yes"
      ;;
    no|n|false)
      printf '%s' "no"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

brief_has_section() {
  local file="$1"
  local section="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  awk -v section="$section" '
    $0 == section { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

brief_has_risk_signals_section() {
  local brief_file="$FEATURE_DIR/brief.md"
  brief_has_section "$brief_file" "## Risk Signals"
}

risk_signal_value_from_brief() {
  local key="$1"
  local brief_file="$FEATURE_DIR/brief.md"
  local value

  value="$(section_key_value "$brief_file" "## Risk Signals" "$key")"
  normalize_yes_no_token "$value"
}

risk_signal_yes_keys_from_brief() {
  local key
  local value

  if ! brief_has_risk_signals_section; then
    return 0
  fi

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    value="$(risk_signal_value_from_brief "$key")"
    if [[ "$value" == "yes" ]]; then
      printf '%s\n' "$key"
    fi
  done < <(risk_signal_keys)
}

high_risk_signals_count_from_brief() {
  local count=0
  while IFS= read -r _key; do
    [[ -n "$_key" ]] || continue
    count=$((count + 1))
  done < <(risk_signal_yes_keys_from_brief)

  printf '%s' "$count"
}

risk_class_from_brief() {
  local brief_file="$FEATURE_DIR/brief.md"
  local risk_class

  risk_class="$(section_key_value "$brief_file" "## Risk Class" "class")"
  risk_class="$(normalize_risk_class_token "$risk_class")"
  printf '%s' "$risk_class"
}

risk_rationale_from_brief() {
  local brief_file="$FEATURE_DIR/brief.md"
  section_key_value "$brief_file" "## Risk Class" "rationale"
}

default_workflow_mode_for_risk_class() {
  local risk_class

  risk_class="$(normalize_risk_class_token "${1:-}")"
  case "$risk_class" in
    trivial)
      printf '%s' "trivial"
      ;;
    high-risk)
      printf '%s' "full"
      ;;
    *)
      printf '%s' "lite"
      ;;
  esac
}

execution_mode_from_brief() {
  local brief_file="$FEATURE_DIR/brief.md"
  local mode

  mode="$(section_key_value "$brief_file" "## Execution Mode" "mode")"
  mode="$(normalize_mode_token "$mode")"
  printf '%s' "$mode"
}

execution_rationale_from_brief() {
  local brief_file="$FEATURE_DIR/brief.md"
  section_key_value "$brief_file" "## Execution Mode" "rationale"
}

workflow_mode_from_brief() {
  local brief_file="$FEATURE_DIR/brief.md"
  local mode

  mode="$(section_key_value "$brief_file" "## Workflow Mode" "mode")"
  mode="$(normalize_mode_token "$mode")"
  printf '%s' "$mode"
}

workflow_rationale_from_brief() {
  local brief_file="$FEATURE_DIR/brief.md"
  section_key_value "$brief_file" "## Workflow Mode" "rationale"
}

implementer_mode_from_plan() {
  local mode

  mode="$(section_key_value "$PLAN_FILE" "## Execution Strategy" "implementer mode")"
  mode="$(normalize_mode_token "$mode")"
  if [[ -z "$mode" ]]; then
    printf '%s' "serial"
    return 0
  fi

  printf '%s' "$mode"
}

implementer_merge_owner_from_plan() {
  section_key_value "$PLAN_FILE" "## Execution Strategy" "merge owner"
}

workflow_roles_for_mode() {
  local mode

  mode="$(normalize_mode_token "${1:-}")"
  case "$mode" in
    trivial)
      printf '%s\n' \
        "orchestrator" \
        "planner" \
        "implementer" \
        "gate-checker"
      ;;
    lite)
      printf '%s\n' \
        "orchestrator" \
        "planner" \
        "implementer" \
        "tester" \
        "gate-checker"
      ;;
    *)
      printf '%s\n' \
        "orchestrator" \
        "planner" \
        "implementer" \
        "tester" \
        "gate-checker" \
        "reviewer" \
        "security"
      ;;
  esac
}

required_handoff_files_for_mode() {
  local mode

  mode="$(normalize_mode_token "${1:-}")"
  printf '%s\n' "implementer-handoff.md"
  case "$mode" in
    lite|full)
      printf '%s\n' "tester-handoff.md"
      ;;
  esac
  case "$mode" in
    full)
      printf '%s\n' "reviewer-handoff.md"
      printf '%s\n' "security-handoff.md"
      ;;
  esac
}

changed_files() {
  local -a files=()
  local range="${GATE_DIFF_RANGE:-}"

  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(git_changed_files_for_repo "$ROOT_DIR" "$range" "${GITHUB_BASE_REF:-}")

  if [[ -f "$BASELINE_FILE" ]]; then
    current_tmp="$(mktemp)"
    filtered_tmp="$(mktemp)"

    if [[ ${#files[@]} -gt 0 ]]; then
      printf '%s\n' "${files[@]}" | sort -u > "$current_tmp"
    else
      : > "$current_tmp"
    fi
    grep -Fxv -f "$BASELINE_FILE" "$current_tmp" > "$filtered_tmp" || true
    cat "$filtered_tmp"
    rm -f "$current_tmp" "$filtered_tmp"
    return 0
  fi

  if [[ ${#files[@]} -gt 0 ]]; then
    printf '%s\n' "${files[@]}" | sort -u
  fi
}

approval_target_path_is_excluded() {
  local path="$1"

  case "$path" in
    "docs/features/$FEATURE_ID/run-log.md"|"docs/features/$FEATURE_ID/artifacts/"*|"docs/context/HANDOFF.md"|"docs/context/CODEX_RESUME.md"|"docs/context/MAINTENANCE_STATUS.md"|"docs/context/sessions/"*)
      return 0
      ;;
  esac

  return 1
}

approval_target_files() {
  changed_files | while IFS= read -r relative_path; do
    [[ -n "$relative_path" ]] || continue
    if approval_target_path_is_excluded "$relative_path"; then
      continue
    fi
    printf '%s\n' "$relative_path"
  done | sort -u
}

# Extract backtick-wrapped file paths from plan.md target files section.
allowed_files_from_plan() {
  if [[ ! -f "$PLAN_FILE" ]]; then
    return 0
  fi

  awk '
    /^## Scope/ { in_scope=1; next }
    /^## / && in_scope { in_scope=0 }
    in_scope && /^- target files:/ { in_targets=1; next }
    in_scope && /^- out-of-scope files:/ { in_targets=0 }
    in_scope && in_targets && /^[[:space:]]*-[[:space:]]*`[^`]+`([[:space:]].*)?$/ {
      if (match($0, /`[^`]+`/)) {
        value = substr($0, RSTART + 1, RLENGTH - 2)
        print value
      }
    }
  ' "$PLAN_FILE" | sed '/^$/d' | sort -u
}

is_workflow_internal_file() {
  local path="$1"

  case "$path" in
    "docs/features/$FEATURE_ID/"* \
    |"docs/context/HANDOFF.md" \
    |"docs/context/CODEX_RESUME.md" \
    |"docs/context/MAINTENANCE_STATUS.md" \
    |"docs/context/DECISIONS.md" \
    |"docs/context/DECISIONS_ARCHIVE.md" \
    |"docs/context/sessions/"*)
      return 0
      ;;
  esac

  return 1
}

utc_now() {
  perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M:%SZ", gmtime(time()))'
}

sha256_file() {
  local path="$1"
  shasum -a 256 "$path" | awk '{print $1}'
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return 0
  fi

  echo "[ERROR] sha256 tool not found" >&2
  exit 1
}

file_digest_or_missing() {
  local path="$1"
  if [[ -f "$path" ]]; then
    sha256_file "$path"
    return 0
  fi
  printf '%s' "missing"
}

is_sha256() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9a-f]{64}$ ]]
}

approval_target_hash() {
  local has_files=0

  {
    echo "feature-id=$FEATURE_ID"
    while IFS= read -r relative_path; do
      [[ -n "$relative_path" ]] || continue
      has_files=1
      printf '%s\t%s\n' "$relative_path" "$(file_digest_or_missing "$ROOT_DIR/$relative_path")"
    done < <(approval_target_files)

    if [[ "$has_files" == "0" ]]; then
      echo "__empty__"
    fi
  } | sha256_stdin
}

is_valid_utc_timestamp() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
