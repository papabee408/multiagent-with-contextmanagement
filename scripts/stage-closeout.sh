#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVE_FEATURE_FILE="$ROOT_DIR/.context/active_feature"
ACTIVE_SESSION_FILE="$ROOT_DIR/.context/active_session"
FEATURE_ID=""
SESSION_FILE=""

source "$ROOT_DIR/scripts/_git_change_helpers.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/stage-closeout.sh [--feature <feature-id>] [--session-file <relative-path>]
EOF
}

resolve_feature_id_or_exit() {
  local feature_id="${1:-}"

  if [[ -n "$feature_id" ]]; then
    printf '%s' "$feature_id"
    return 0
  fi

  if [[ -f "$ACTIVE_FEATURE_FILE" ]]; then
    feature_id="$(tr -d ' \n\r\t' < "$ACTIVE_FEATURE_FILE")"
  fi

  if [[ -z "$feature_id" ]]; then
    echo "[ERROR] feature-id is required. Set .context/active_feature or pass --feature." >&2
    exit 1
  fi

  printf '%s' "$feature_id"
}

resolve_session_file() {
  local session_file="${1:-}"

  if [[ -z "$session_file" && -s "$ACTIVE_SESSION_FILE" ]]; then
    session_file="$(tr -d '\r' < "$ACTIVE_SESSION_FILE")"
  fi

  session_file="${session_file#$ROOT_DIR/}"
  session_file="$(printf '%s' "$session_file" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

  if [[ -z "$session_file" ]]; then
    return 0
  fi

  if [[ "$session_file" == /* || "$session_file" == *".."* ]]; then
    echo "[ERROR] --session-file must stay inside the repository" >&2
    exit 1
  fi

  printf '%s' "$session_file"
}

print_if_exists() {
  local relative_path="$1"
  if [[ -e "$ROOT_DIR/$relative_path" ]]; then
    printf '%s\n' "$relative_path"
  fi
}

collect_candidate_paths() {
  local feature_id="$1"
  local session_file="$2"

  print_if_exists "docs/features/$feature_id/run-log.md"

  if [[ -d "$ROOT_DIR/docs/features/$feature_id/artifacts" ]]; then
    find "$ROOT_DIR/docs/features/$feature_id/artifacts" -type f | sort | while IFS= read -r absolute_path; do
      printf '%s\n' "${absolute_path#$ROOT_DIR/}"
    done
  fi

  for relative_path in \
    "docs/context/HANDOFF.md" \
    "docs/context/CODEX_RESUME.md" \
    "docs/context/MAINTENANCE_STATUS.md"; do
    print_if_exists "$relative_path"
  done

  print_if_exists "$session_file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      FEATURE_ID="${2:-}"
      if [[ -z "$FEATURE_ID" ]]; then
        echo "[ERROR] --feature requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --session-file)
      SESSION_FILE="${2:-}"
      if [[ -z "$SESSION_FILE" ]]; then
        echo "[ERROR] --session-file requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unexpected argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

FEATURE_ID="$(resolve_feature_id_or_exit "$FEATURE_ID")"
SESSION_FILE="$(resolve_session_file "$SESSION_FILE")"

candidates_tmp="$(mktemp)"
changed_tmp="$(mktemp)"
trap 'rm -f "$candidates_tmp" "$changed_tmp"' EXIT

collect_candidate_paths "$FEATURE_ID" "$SESSION_FILE" | sort -u > "$candidates_tmp"

if [[ ! -s "$candidates_tmp" ]]; then
  echo "[INFO] no closeout files found for feature: $FEATURE_ID"
  exit 0
fi

git_local_changed_files "$ROOT_DIR" | grep -Fx -f "$candidates_tmp" > "$changed_tmp" || true

if [[ ! -s "$changed_tmp" ]]; then
  echo "[INFO] no changed closeout files to stage for feature: $FEATURE_ID"
  exit 0
fi

changed_paths=()
while IFS= read -r relative_path; do
  [[ -n "$relative_path" ]] || continue
  changed_paths+=("$relative_path")
done < "$changed_tmp"

git -C "$ROOT_DIR" add -- "${changed_paths[@]}"

echo "[OK] staged closeout files for feature: $FEATURE_ID"
printf ' - %s\n' "${changed_paths[@]}"
