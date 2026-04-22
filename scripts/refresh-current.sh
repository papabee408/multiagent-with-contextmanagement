#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -gt 0 ]]; then
  exec bash "$ROOT_DIR/scripts/status-task.sh" "$@"
fi

exec bash "$ROOT_DIR/scripts/status-task.sh"
