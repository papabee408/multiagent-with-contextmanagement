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
    lite|full|serial|parallel)
      printf '%s' "$value"
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

workflow_mode_from_brief() {
  local brief_file="$FEATURE_DIR/brief.md"
  local mode

  mode="$(section_key_value "$brief_file" "## Workflow Mode" "mode")"
  mode="$(normalize_mode_token "$mode")"
  if [[ -z "$mode" ]]; then
    printf '%s' "full"
    return 0
  fi

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

is_doc_file() {
  local path="$1"
  [[ "$path" == docs/* || "$path" == "AGENTS.md" || "$path" == "README.md" ]]
}

utc_now() {
  perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M:%SZ", gmtime(time()))'
}

sha256_file() {
  local path="$1"
  shasum -a 256 "$path" | awk '{print $1}'
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

is_valid_utc_timestamp() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
