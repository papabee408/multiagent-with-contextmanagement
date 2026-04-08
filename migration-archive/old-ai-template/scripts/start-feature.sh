#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURE_ID=""
RISK_CLASS=""
RISK_RATIONALE=""
WORKFLOW_MODE=""
WORKFLOW_REASON=""
EXECUTION_MODE=""
EXECUTION_REASON=""
PACKET_CREATED=0
SETUP_STAMP_FILE="$ROOT_DIR/.context/setup-check.done"

usage() {
  cat <<'EOF'
Usage:
  scripts/start-feature.sh [--risk-class trivial|standard|high-risk] [--risk-rationale "<why>"] [--workflow-mode trivial|lite|full] [--workflow-reason "<why>"] [--execution-mode single|multi-agent] [--execution-reason "<why>"] <feature-id>
EOF
}

setup_check_status() {
  if [[ ! -f "$SETUP_STAMP_FILE" ]]; then
    return 0
  fi

  awk -F= '/^status=/{print $2; exit}' "$SETUP_STAMP_FILE"
}

setup_check_needs_run() {
  local status=""

  if [[ ! -f "$SETUP_STAMP_FILE" ]]; then
    return 0
  fi

  status="$(setup_check_status)"
  [[ "$status" == "alert" ]]
}

write_setup_success_stamp() {
  {
    printf 'status=ok\n'
    printf 'checked_at_utc=%s\n' "$(date -u +"%Y-%m-%d %H:%M:%SZ")"
  } > "$SETUP_STAMP_FILE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --risk-class)
      RISK_CLASS="${2:-}"
      shift 2
      ;;
    --risk-rationale)
      RISK_RATIONALE="${2:-}"
      shift 2
      ;;
    --workflow-mode)
      WORKFLOW_MODE="${2:-}"
      shift 2
      ;;
    --workflow-reason)
      WORKFLOW_REASON="${2:-}"
      shift 2
      ;;
    --execution-mode)
      EXECUTION_MODE="${2:-}"
      shift 2
      ;;
    --execution-reason)
      EXECUTION_REASON="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FEATURE_ID="${1:-}"
      shift
      ;;
  esac
done

if [[ -z "$FEATURE_ID" ]]; then
  usage
  exit 1
fi

mkdir -p "$ROOT_DIR/.context"

if setup_check_needs_run; then
  if "$ROOT_DIR/scripts/check-project-setup.sh"; then
    write_setup_success_stamp
  else
    rm -f "$SETUP_STAMP_FILE"
    echo "[ALERT] project setup check reported issues. The setup check will run again on the next start-feature until it passes."
  fi
fi

if [[ -d "$ROOT_DIR/docs/features/$FEATURE_ID" ]]; then
  if [[ -n "$RISK_CLASS" || -n "$RISK_RATIONALE" || -n "$WORKFLOW_MODE" || -n "$WORKFLOW_REASON" || -n "$EXECUTION_MODE" || -n "$EXECUTION_REASON" ]]; then
    echo "[ERROR] start-feature.sh only sets mode values while creating a new feature packet." >&2
    echo "Use scripts/promote-workflow.sh or scripts/workflow-mode.sh / scripts/execution-mode.sh with --allow-change only after explicit user approval." >&2
    exit 1
  fi
  "$ROOT_DIR/scripts/set-active-feature.sh" "$FEATURE_ID"
else
  feature_packet_cmd=("$ROOT_DIR/scripts/feature-packet.sh")
  [[ -n "$RISK_CLASS" ]] && feature_packet_cmd+=(--risk-class "$RISK_CLASS")
  [[ -n "$RISK_RATIONALE" ]] && feature_packet_cmd+=(--risk-rationale "$RISK_RATIONALE")
  [[ -n "$WORKFLOW_MODE" ]] && feature_packet_cmd+=(--workflow-mode "$WORKFLOW_MODE")
  [[ -n "$WORKFLOW_REASON" ]] && feature_packet_cmd+=(--workflow-reason "$WORKFLOW_REASON")
  [[ -n "$EXECUTION_MODE" ]] && feature_packet_cmd+=(--execution-mode "$EXECUTION_MODE")
  [[ -n "$EXECUTION_REASON" ]] && feature_packet_cmd+=(--execution-reason "$EXECUTION_REASON")
  feature_packet_cmd+=("$FEATURE_ID")
  "${feature_packet_cmd[@]}"
  PACKET_CREATED=1
fi

echo "[OK] feature workflow entry ready: $FEATURE_ID"
