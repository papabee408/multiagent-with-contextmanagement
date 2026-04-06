#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TITLE="${1:-}"
DECISION="${2:-}"
REASON="${3:-}"
DECISIONS_FILE="$ROOT_DIR/docs/context/DECISIONS.md"

if [[ -z "$TITLE" || -z "$DECISION" || -z "$REASON" ]]; then
  echo "Usage: bash scripts/log-decision.sh \"<title>\" \"<decision>\" \"<reason>\"" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/docs/context"
if [[ ! -f "$DECISIONS_FILE" ]]; then
  cat > "$DECISIONS_FILE" <<'EOF'
# Decisions
EOF
fi

{
  echo ""
  echo "## $(utc_now) - $TITLE"
  echo "- decision: $DECISION"
  echo "- reason: $REASON"
} >> "$DECISIONS_FILE"

echo "[OK] decision logged"
