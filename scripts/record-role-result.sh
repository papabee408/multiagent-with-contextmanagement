#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_run_log_helpers.sh"
source "$ROOT_DIR/scripts/_role_receipt_helpers.sh"

FEATURE_ID=""
AGENT_ID=""
SCOPE=""
RQ_COVERED=""
RQ_MISSING=""
RESULT=""
EVIDENCE=""
NEXT_ACTION=""
TOUCHED_FILES=""
APPROVAL_TARGET_HASH=""

usage() {
  cat <<'EOF'
Usage:
  scripts/record-role-result.sh [--feature <feature-id>] <role> \
    --agent-id <id> \
    --scope "<scope>" \
    --rq-covered "<rq list>" \
    --rq-missing "<rq list>" \
    --result PASS|FAIL|BLOCKED \
    --evidence "<evidence>" \
    --next-action "<next action>" \
    --touched-files "<file list or []>"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      FEATURE_ID="${2:-}"
      shift 2
      ;;
    --agent-id)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --scope)
      SCOPE="${2:-}"
      shift 2
      ;;
    --rq-covered)
      RQ_COVERED="${2:-}"
      shift 2
      ;;
    --rq-missing)
      RQ_MISSING="${2:-}"
      shift 2
      ;;
    --result)
      RESULT="${2:-}"
      shift 2
      ;;
    --evidence)
      EVIDENCE="${2:-}"
      shift 2
      ;;
    --next-action)
      NEXT_ACTION="${2:-}"
      shift 2
      ;;
    --touched-files)
      TOUCHED_FILES="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

ROLE="${1:-}"
if [[ -z "$ROLE" ]]; then
  usage
  exit 1
fi
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-id)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --scope)
      SCOPE="${2:-}"
      shift 2
      ;;
    --rq-covered)
      RQ_COVERED="${2:-}"
      shift 2
      ;;
    --rq-missing)
      RQ_MISSING="${2:-}"
      shift 2
      ;;
    --result)
      RESULT="${2:-}"
      shift 2
      ;;
    --evidence)
      EVIDENCE="${2:-}"
      shift 2
      ;;
    --next-action)
      NEXT_ACTION="${2:-}"
      shift 2
      ;;
    --touched-files)
      TOUCHED_FILES="${2:-}"
      shift 2
      ;;
    *)
      echo "[ERROR] unexpected argument: $1" >&2
      exit 1
      ;;
  esac
done

FEATURE_ID="$(resolve_feature_id_or_exit "$FEATURE_ID")"
validate_role_or_exit "$ROLE"
source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"

RESULT="$(printf '%s' "$RESULT" | tr '[:lower:]' '[:upper:]')"
case "$RESULT" in
  PASS|FAIL|BLOCKED)
    ;;
  *)
    echo "[ERROR] --result must be PASS, FAIL, or BLOCKED" >&2
    exit 1
    ;;
esac

for required_name in AGENT_ID SCOPE RQ_COVERED RQ_MISSING EVIDENCE NEXT_ACTION TOUCHED_FILES; do
  if [[ -z "${!required_name}" ]]; then
    echo "[ERROR] missing required flag for role result: ${required_name}" >&2
    exit 1
  fi
done

case "$ROLE" in
  reviewer|security)
    APPROVAL_TARGET_HASH="$(approval_target_hash)"
    ;;
esac

RUN_LOG="$(ensure_run_log_or_exit "$FEATURE_ID")"
BLOCK_FILE="$(mktemp)"
trap 'rm -f "$BLOCK_FILE"' EXIT

cat > "$BLOCK_FILE" <<EOF
- agent-id: $(normalize_line "$AGENT_ID")
- scope: $(normalize_line "$SCOPE")
- rq_covered: $(normalize_line "$RQ_COVERED")
- rq_missing: $(normalize_line "$RQ_MISSING")
- result: $RESULT
- evidence: $(normalize_line "$EVIDENCE")
- next_action: $(normalize_line "$NEXT_ACTION")
EOF

replace_role_section_or_exit "$RUN_LOG" "$ROLE" "$BLOCK_FILE"
write_role_receipt \
  "$FEATURE_ID" \
  "$ROLE" \
  "$(normalize_line "$AGENT_ID")" \
  "$(normalize_line "$SCOPE")" \
  "$(normalize_line "$RQ_COVERED")" \
  "$(normalize_line "$RQ_MISSING")" \
  "$RESULT" \
  "$(normalize_line "$EVIDENCE")" \
  "$(normalize_line "$NEXT_ACTION")" \
  "$(normalize_line "$TOUCHED_FILES")" \
  "$APPROVAL_TARGET_HASH"

echo "[OK] role result recorded: $ROLE"
