#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh" "${1:-}"

DEFAULT_MAX="${MAX_FILE_LINES:-700}"
EXCEPTIONS_FILE="$SCRIPT_DIR/size-exceptions.txt"

lookup_override() {
  local path="$1"
  if [[ ! -f "$EXCEPTIONS_FILE" ]]; then
    return 1
  fi
  awk -v target="$path" '
    $0 ~ /^[[:space:]]*#/ { next }
    NF >= 2 && $1 == target { print $2; exit 0 }
  ' "$EXCEPTIONS_FILE"
}

changed=()
while IFS= read -r line; do
  [[ -n "$line" ]] && changed+=("$line")
done < <(changed_files)
if [[ ${#changed[@]} -eq 0 ]]; then
  echo "[PASS] file-size (no changes)"
  exit 0
fi

violations=()
for path in "${changed[@]}"; do
  abs="$ROOT_DIR/$path"
  [[ -f "$abs" ]] || continue

  case "$path" in
    *.sh|*.mjs|*.cjs|*.js|*.jsx|*.ts|*.tsx|*.py|*.rb|*.go|*.java|*.kt|*.swift|*.html|*.css|*.scss)
      ;;
    *)
      continue
      ;;
  esac

  lines=$(wc -l < "$abs" | tr -d ' ')
  max="$DEFAULT_MAX"
  override="$(lookup_override "$path" || true)"
  if [[ -n "$override" ]]; then
    max="$override"
  fi

  if (( lines > max )); then
    violations+=("$path ($lines > $max)")
  fi
done

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "[FAIL] file-size"
  printf ' - %s\n' "${violations[@]}"
  exit 1
fi

echo "[PASS] file-size"
