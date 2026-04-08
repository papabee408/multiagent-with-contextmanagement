#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

TASK_ID="$(resolve_task_id_or_exit "${1:-}")"

echo "[FAIL] independent-review"
echo " - task=$TASK_ID"
echo " - the base template does not enable independent review fields or completion gates"
echo " - use verification + scope review + quality review in the core workflow"
echo " - if you need independent review, add it as an explicit optional extension first"
exit 1
