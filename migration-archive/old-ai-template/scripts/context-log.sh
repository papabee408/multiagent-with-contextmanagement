#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

readonly CONTEXT_DIR="docs/context"
readonly SESSIONS_DIR="$CONTEXT_DIR/sessions"
readonly STATE_DIR=".context"
readonly ACTIVE_SESSION_FILE="$STATE_DIR/active_session"
readonly README_FILE="$CONTEXT_DIR/README.md"
readonly HANDOFF_FILE="$CONTEXT_DIR/HANDOFF.md"
readonly DECISIONS_FILE="$CONTEXT_DIR/DECISIONS.md"
readonly DECISIONS_ARCHIVE_FILE="$CONTEXT_DIR/DECISIONS_ARCHIVE.md"
readonly PROJECT_FILE="$CONTEXT_DIR/PROJECT.md"
readonly CONVENTIONS_FILE="$CONTEXT_DIR/CONVENTIONS.md"
readonly WORKFLOW_FILE="$CONTEXT_DIR/CODEX_WORKFLOW.md"
readonly MAINTENANCE_FILE="$CONTEXT_DIR/MAINTENANCE.md"
readonly MAINTENANCE_STATUS_FILE="$CONTEXT_DIR/MAINTENANCE_STATUS.md"
readonly SNAPSHOT_FILE="$CONTEXT_DIR/CODEX_RESUME.md"
readonly SNAPSHOT_DECISION_COUNT=5
readonly SNAPSHOT_SESSION_TAIL_LINES=30
readonly NOTE_MAX_CHARS=280
readonly DEFAULT_ARCHIVE_KEEP=40
readonly MONTHLY_ARCHIVE_KEEP=40
readonly MONTHLY_SESSION_WARN_COUNT=300
readonly MONTHLY_CONTEXT_WARN_KB=4096

print_usage() {
  cat <<'EOF'
Usage:
  scripts/context-log.sh init
  scripts/context-log.sh start "<session-title>"
  scripts/context-log.sh note "<work-note>"
  scripts/context-log.sh decision "<title>" "<decision>" "<reason>"
  scripts/context-log.sh archive-decisions [keep-count]
  scripts/context-log.sh monthly
  scripts/context-log.sh finish "<summary>" "<next-step>"
  scripts/context-log.sh snapshot
  scripts/context-log.sh resume
  scripts/context-log.sh resume-lite
  scripts/context-log.sh status

Examples:
  scripts/context-log.sh init
  scripts/context-log.sh start "discord-command-router"
  scripts/context-log.sh note "Added slash command parser draft"
  scripts/context-log.sh decision "Command framework" "Use discord.js v14" "Stable ecosystem"
  scripts/context-log.sh archive-decisions 30
  scripts/context-log.sh monthly
  scripts/context-log.sh finish "Implemented context logging workflow" "Build bot bootstrap module"
  scripts/context-log.sh snapshot
  scripts/context-log.sh resume
EOF
}

now_utc() {
  date -u +"%Y-%m-%d %H:%M:%SZ"
}

file_stamp() {
  date -u +"%Y%m%d-%H%M%S"
}

slugify() {
  local raw="$1"
  local lowered
  lowered="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$lowered" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/--+/-/g'
}

count_decision_entries() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    printf '0'
    return
  fi

  awk '
    /^### [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}Z \| / { count++ }
    END { print count + 0 }
  ' "$file_path"
}

ensure_structure() {
  mkdir -p "$SESSIONS_DIR" "$STATE_DIR"
  touch "$ACTIVE_SESSION_FILE"

  if [[ ! -f "$README_FILE" ]]; then
    cat > "$README_FILE" <<'EOF'
# Context Logging Guide

This folder keeps durable project memory so development can continue after any context reset.

## File Roles

- `PROJECT.md`: Stable project brief (goal, stack, conventions).
- `CONVENTIONS.md`: Reuse, hardcoding, naming, and review conventions.
- `HANDOFF.md`: Latest checkpoint for next session.
- `DECISIONS.md`: Active architecture and policy decisions.
- `DECISIONS_ARCHIVE.md`: Archived historical decisions.
- `CODEX_WORKFLOW.md`: Codex session operating guide.
- `MAINTENANCE.md`: Monthly maintenance routine and thresholds.
- `MAINTENANCE_STATUS.md`: Latest maintenance metrics snapshot.
- `CODEX_RESUME.md`: Compact snapshot for context-reset recovery.
- `sessions/*.md`: Chronological session logs.

## Daily Workflow

1. `scripts/context-log.sh start "<title>"`
2. `scripts/context-log.sh note "<what changed>"` (keep notes concise)
3. `scripts/context-log.sh decision "<title>" "<decision>" "<reason>"` (optional)
4. `scripts/context-log.sh finish "<summary>" "<next-step>"`
5. (Optional) `scripts/context-log.sh snapshot`

## Monthly Workflow

1. `scripts/context-log.sh monthly`
2. Review `docs/context/MAINTENANCE_STATUS.md`
3. If warnings are triggered, archive additional decisions or compress old session notes.

## Codex Resume Workflow

1. Run `scripts/context-log.sh resume-lite`.
2. Read `HANDOFF.md` + `CODEX_RESUME.md` first.
3. Open deep-dive files only when needed.
EOF
  fi

  if [[ ! -f "$PROJECT_FILE" ]]; then
    cat > "$PROJECT_FILE" <<EOF
# Project Brief

## Identity
- project-name: $(basename "$ROOT_DIR")
- repo-slug: $(basename "$ROOT_DIR")
- product-type: software project

## Product
- Primary goal:
- Primary users:
- Success signals:

## Stack
- Runtime:
- Framework:
- Data layer:

## Constraints
- Keep architecture and coding rules documented before implementation.
- Keep reusable logic/components/config centralized.

## Working Agreements
- Record active decisions in DECISIONS.md and archive old ones via the archive-decisions command.
- End each session with the finish command.
- Keep HANDOFF.md actionable for the next contributor.
EOF
  fi

  if [[ ! -f "$CONVENTIONS_FILE" ]]; then
    cat > "$CONVENTIONS_FILE" <<'EOF'
# Coding Conventions

## Reuse First
- Repeated UI/logic/config should be extracted into shared modules instead of copied.

## Configuration and Constants
- Keep meaningful limits, labels, state values, and endpoints out of inline literals.

## Components and Modules
- Separate UI composition, domain logic, and external integration responsibilities.

## Naming and Data Shapes
- Prefer stable domain terms and normalized internal shapes.

## Tests and Change Hygiene
- Update tests with every behavior change and remove temporary debug code before merge.
EOF
  fi

  if [[ ! -f "$HANDOFF_FILE" ]]; then
    cat > "$HANDOFF_FILE" <<EOF
# Current Handoff

- Last Updated (UTC): $(now_utc)
- Last Session File: none

## What Was Done
- Initialized context logging system.

## Next Task
- Start first development session with \`scripts/context-log.sh start "<title>"\`.

## Resume Checklist
- Read this file first.
- Read \`CODEX_RESUME.md\`.
- Open deep-dive files only if needed.
EOF
  fi

  if [[ ! -f "$DECISIONS_FILE" ]]; then
    cat > "$DECISIONS_FILE" <<'EOF'
# Decision Log

Use this file for active architecture, tooling, and policy decisions.
Archive older entries with `scripts/context-log.sh archive-decisions [keep-count]`.

## Entry Template

### YYYY-MM-DD HH:MM:SSZ | Decision title
- Decision:
- Reason:
- Impact:
EOF
  fi

  if [[ ! -f "$DECISIONS_ARCHIVE_FILE" ]]; then
    cat > "$DECISIONS_ARCHIVE_FILE" <<'EOF'
# Decision Archive

Historical decisions moved out of `DECISIONS.md` to keep startup context lightweight.

## Archived Entries
EOF
  fi

  if [[ ! -f "$WORKFLOW_FILE" ]]; then
    cat > "$WORKFLOW_FILE" <<'EOF'
# Codex Context Workflow

Use this flow to survive Codex context resets during long-term development.

## Start of Session

1. Run `scripts/context-log.sh resume-lite`.
2. Read `docs/context/HANDOFF.md` and `docs/context/CODEX_RESUME.md` first.
3. Open deep-dive files only if needed (`DECISIONS.md`, latest session file, `DECISIONS_ARCHIVE.md`).
4. Start a fresh session log:
   `scripts/context-log.sh start "<session-title>"`

## During Session

- Record progress frequently:
  `scripts/context-log.sh note "<what changed>"`
- Record meaningful decisions:
  `scripts/context-log.sh decision "<title>" "<decision>" "<reason>"`

## End of Session

1. Run:
   `scripts/context-log.sh finish "<summary>" "<next-step>"`
2. This also refreshes `docs/context/CODEX_RESUME.md` automatically.

## Monthly Maintenance

1. Run `scripts/context-log.sh monthly`.
2. Review `docs/context/MAINTENANCE_STATUS.md`.
3. If warnings are triggered, archive more decisions or condense old session logs.
EOF
  fi

  if [[ ! -f "$MAINTENANCE_FILE" ]]; then
    cat > "$MAINTENANCE_FILE" <<EOF
# Context Maintenance

Run this routine once per month to keep startup context lightweight.

## Monthly Command

- Run: \`scripts/context-log.sh monthly\`
- Output: \`docs/context/MAINTENANCE_STATUS.md\`

## What Monthly Does

1. Archives old decisions from \`DECISIONS.md\` into \`DECISIONS_ARCHIVE.md\`, keeping the latest $MONTHLY_ARCHIVE_KEEP active entries.
2. Regenerates \`CODEX_RESUME.md\`.
3. Captures current metrics in \`MAINTENANCE_STATUS.md\`.

## Warning Thresholds

- Session files warning: more than $MONTHLY_SESSION_WARN_COUNT files in \`docs/context/sessions\`
- Context size warning: more than $MONTHLY_CONTEXT_WARN_KB KB for \`docs/context\`

If warnings trigger, tighten note verbosity and archive decisions sooner.
EOF
  fi
}

require_active_session() {
  if [[ ! -s "$ACTIVE_SESSION_FILE" ]]; then
    echo "No active session. Run: scripts/context-log.sh start \"<title>\"" >&2
    exit 1
  fi
}

read_active_session_path() {
  local session_path
  session_path="$(cat "$ACTIVE_SESSION_FILE")"
  if [[ -z "$session_path" || ! -f "$session_path" ]]; then
    echo "Active session path is invalid: $session_path" >&2
    exit 1
  fi
  printf '%s' "$session_path"
}

read_last_session_from_handoff() {
  if [[ ! -f "$HANDOFF_FILE" ]]; then
    printf ''
    return
  fi

  sed -n 's/^- Last Session File: //p' "$HANDOFF_FILE" | head -n 1
}

latest_session_file() {
  local from_handoff
  from_handoff="$(read_last_session_from_handoff)"
  if [[ -n "$from_handoff" && -f "$from_handoff" ]]; then
    printf '%s' "$from_handoff"
    return
  fi

  local latest
  latest="$(ls -1 "$SESSIONS_DIR"/*.md 2>/dev/null | sort | tail -n 1 || true)"
  printf '%s' "$latest"
}

extract_latest_decisions() {
  if [[ ! -f "$DECISIONS_FILE" ]]; then
    return
  fi

  awk -v max="$SNAPSHOT_DECISION_COUNT" '
    /^### / {
      if ($2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
        count++
        block[count] = $0
        collecting = 1
      } else {
        collecting = 0
      }
      next
    }
    collecting == 1 && count > 0 {
      block[count] = block[count] ORS $0
    }
    END {
      if (count == 0) {
        exit
      }
      start = count - max + 1
      if (start < 1) {
        start = 1
      }
      for (i = start; i <= count; i++) {
        print block[i]
        if (i < count) {
          print ""
        }
      }
    }
  ' "$DECISIONS_FILE"
}

read_next_task() {
  if [[ ! -f "$HANDOFF_FILE" ]]; then
    printf 'No next task recorded.'
    return
  fi

  local task
  task="$(awk '
    /^## Next Task$/ {
      getline
      sub(/^- /, "")
      print
      found = 1
      exit
    }
    END {
      if (!found) {
        print ""
      }
    }
  ' "$HANDOFF_FILE")"

  if [[ -z "$task" ]]; then
    printf 'No next task recorded.'
    return
  fi

  printf '%s' "$task"
}

split_active_decisions() {
  local keep_count="$1"
  local active_output="$2"
  local archive_output="$3"

  awk -v keep="$keep_count" -v active_output="$active_output" -v archive_output="$archive_output" '
    function is_decision_header(line) {
      return line ~ /^### [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}Z \| /
    }

    {
      if (is_decision_header($0)) {
        entry_count++
        in_entry = 1
      }

      if (!in_entry) {
        header = header $0 ORS
        next
      }

      entries[entry_count] = entries[entry_count] $0 ORS
    }

    END {
      printf "%s", header > active_output

      archive_limit = entry_count - keep
      if (archive_limit < 0) {
        archive_limit = 0
      }

      for (i = 1; i <= entry_count; i++) {
        if (i <= archive_limit) {
          printf "%s", entries[i] >> archive_output
        } else {
          printf "%s", entries[i] >> active_output
        }
      }
    }
  ' "$DECISIONS_FILE"
}

archive_active_decisions() {
  local keep_count="${1:-$DEFAULT_ARCHIVE_KEEP}"

  if ! [[ "$keep_count" =~ ^[0-9]+$ ]]; then
    echo "Keep count must be a non-negative integer." >&2
    exit 1
  fi

  ensure_structure

  local total_entries
  total_entries="$(count_decision_entries "$DECISIONS_FILE")"
  if (( total_entries <= keep_count )); then
    echo "No archive needed. Active decisions: $total_entries (keep: $keep_count)."
    return
  fi

  local active_tmp
  local archive_tmp
  active_tmp="$(mktemp)"
  archive_tmp="$(mktemp)"
  : > "$archive_tmp"

  split_active_decisions "$keep_count" "$active_tmp" "$archive_tmp"

  mv "$active_tmp" "$DECISIONS_FILE"

  if [[ -s "$archive_tmp" ]]; then
    printf '\n' >> "$DECISIONS_ARCHIVE_FILE"
    cat "$archive_tmp" >> "$DECISIONS_ARCHIVE_FILE"
  fi

  rm -f "$archive_tmp"

  local moved_count
  moved_count=$(( total_entries - keep_count ))
  echo "Archived $moved_count decision entries to $DECISIONS_ARCHIVE_FILE (active keep: $keep_count)."
}

generate_maintenance_status() {
  ensure_structure

  local session_count
  local context_kb
  local active_decision_count
  local archived_decision_count
  local workflow_kpis
  session_count="$(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
  context_kb="$(du -sk "$CONTEXT_DIR" | awk '{print $1}')"
  active_decision_count="$(count_decision_entries "$DECISIONS_FILE")"
  archived_decision_count="$(count_decision_entries "$DECISIONS_ARCHIVE_FILE")"

  local session_threshold_state="ok"
  local context_threshold_state="ok"
  if (( session_count > MONTHLY_SESSION_WARN_COUNT )); then
    session_threshold_state="warning"
  fi
  if (( context_kb > MONTHLY_CONTEXT_WARN_KB )); then
    context_threshold_state="warning"
  fi

  if [[ -f "$ROOT_DIR/scripts/report-template-kpis.sh" ]]; then
    workflow_kpis="$(bash "$ROOT_DIR/scripts/report-template-kpis.sh" --maintenance-section)"
  else
    workflow_kpis="- workflow KPI report unavailable"
  fi

  cat > "$MAINTENANCE_STATUS_FILE" <<EOF
# Context Maintenance Status

- Generated At (UTC): $(now_utc)
- Session Files: $session_count
- Context Size (KB): $context_kb
- Active Decisions: $active_decision_count
- Archived Decisions: $archived_decision_count

## Threshold Checks

- Session file threshold ($MONTHLY_SESSION_WARN_COUNT): $session_threshold_state
- Context size threshold in KB ($MONTHLY_CONTEXT_WARN_KB): $context_threshold_state

## Workflow KPIs

$workflow_kpis

## Next Actions

- If either threshold is warning, run \`scripts/context-log.sh archive-decisions\` with a lower keep count and tighten note verbosity.
- Review the workflow KPI mix before changing default routing or reviewer/security policy.
- Keep startup reading focused on \`HANDOFF.md\` and \`CODEX_RESUME.md\`.
EOF
}

generate_snapshot() {
  local latest_session
  latest_session="$(latest_session_file)"

  local next_task
  next_task="$(read_next_task)"

  local decisions_excerpt
  decisions_excerpt="$(extract_latest_decisions)"
  if [[ -z "$decisions_excerpt" ]]; then
    decisions_excerpt="- No active decisions recorded yet."
  fi

  cat > "$SNAPSHOT_FILE" <<EOF
# Codex Resume Snapshot

- Generated At (UTC): $(now_utc)
- Primary Next Task: $next_task
- Latest Session File: ${latest_session:-none}
- Active Decision Log: $DECISIONS_FILE
- Decision Archive: $DECISIONS_ARCHIVE_FILE

## Resume Order (New Codex Chat)

1. Read \`docs/context/HANDOFF.md\`.
2. Read \`docs/context/CODEX_RESUME.md\`.
3. Open deep-dive files only if needed:
   - \`docs/context/DECISIONS.md\`
   - latest session file
   - \`docs/context/DECISIONS_ARCHIVE.md\`

## Current Handoff

$(cat "$HANDOFF_FILE")

## Latest Active Decisions (up to $SNAPSHOT_DECISION_COUNT)

$decisions_excerpt

## Latest Session Excerpt
EOF

  if [[ -n "$latest_session" && -f "$latest_session" ]]; then
    {
      echo ""
      echo "Source: $latest_session"
      echo ""
      echo '```text'
      tail -n "$SNAPSHOT_SESSION_TAIL_LINES" "$latest_session"
      echo '```'
    } >> "$SNAPSHOT_FILE"
  else
    {
      echo ""
      echo "- No session file found yet."
    } >> "$SNAPSHOT_FILE"
  fi

  cat >> "$SNAPSHOT_FILE" <<'EOF'

## Operational Commands

- Start: `scripts/context-log.sh start "<session-title>"`
- Note: `scripts/context-log.sh note "<work-note>"`
- Decision: `scripts/context-log.sh decision "<title>" "<decision>" "<reason>"`
- Archive decisions: `scripts/context-log.sh archive-decisions [keep-count]`
- Monthly maintenance: `scripts/context-log.sh monthly`
- Finish: `scripts/context-log.sh finish "<summary>" "<next-step>"`
EOF
}

print_resume_prompt() {
  local next_task="$1"
  local latest_session="$2"

  cat <<EOF
---BEGIN CODEX RESUME PROMPT---
You are continuing this project after a context reset.

Read these files in order:
1. docs/context/HANDOFF.md
2. docs/context/CODEX_RESUME.md

Optional deep-dive files (open only if needed):
- docs/context/DECISIONS.md
- ${latest_session:-docs/context/sessions/<latest>.md}
- docs/context/DECISIONS_ARCHIVE.md

Current next task:
- $next_task

After reading, start logging immediately:
- scripts/context-log.sh start "<new-session-title>"

While implementing:
- scripts/context-log.sh note "<progress>"
- scripts/context-log.sh decision "<title>" "<decision>" "<reason>"  # when needed

At session end:
- scripts/context-log.sh finish "<summary>" "<next-step>"
---END CODEX RESUME PROMPT---
EOF
}

cmd_init() {
  ensure_structure
  generate_snapshot
  generate_maintenance_status
  echo "Initialized context logging structure."
}

cmd_start() {
  local title="${1:-}"
  if [[ -z "$title" ]]; then
    echo "Session title is required." >&2
    exit 1
  fi

  ensure_structure

  if [[ -s "$ACTIVE_SESSION_FILE" ]]; then
    echo "An active session already exists: $(cat "$ACTIVE_SESSION_FILE")" >&2
    echo "Finish it first or clear .context/active_session manually." >&2
    exit 1
  fi

  local slug
  slug="$(slugify "$title")"
  if [[ -z "$slug" ]]; then
    slug="session"
  fi

  local session_file
  session_file="$SESSIONS_DIR/$(file_stamp)-${slug}.md"

  cat > "$session_file" <<EOF
# Session: $title

- Started At (UTC): $(now_utc)
- Status: in_progress

## Goal
- Define the concrete outcome for this session.

## Work Log
- $(now_utc) | Session started.
EOF

  printf '%s\n' "$session_file" > "$ACTIVE_SESSION_FILE"
  echo "Started session: $session_file"
}

cmd_note() {
  local note="${1:-}"
  if [[ -z "$note" ]]; then
    echo "Note content is required." >&2
    exit 1
  fi

  local note_length
  note_length=${#note}
  if (( note_length > NOTE_MAX_CHARS )); then
    echo "Note is too long ($note_length chars). Maximum is $NOTE_MAX_CHARS chars. Summarize and retry." >&2
    exit 1
  fi

  ensure_structure
  require_active_session

  local session_file
  session_file="$(read_active_session_path)"
  printf -- "- %s | %s\n" "$(now_utc)" "$note" >> "$session_file"
  echo "Appended note to $session_file"
}

cmd_decision() {
  local title="${1:-}"
  local decision="${2:-}"
  local reason="${3:-}"

  if [[ -z "$title" || -z "$decision" || -z "$reason" ]]; then
    echo "Usage: scripts/context-log.sh decision \"<title>\" \"<decision>\" \"<reason>\"" >&2
    exit 1
  fi

  ensure_structure

  cat >> "$DECISIONS_FILE" <<EOF

### $(now_utc) | $title
- Decision: $decision
- Reason: $reason
- Impact: TBD
EOF

  echo "Added decision: $title"
}

cmd_archive_decisions() {
  local keep_count="${1:-$DEFAULT_ARCHIVE_KEEP}"

  archive_active_decisions "$keep_count"
  generate_snapshot
  generate_maintenance_status
}

cmd_monthly() {
  ensure_structure
  archive_active_decisions "$MONTHLY_ARCHIVE_KEEP"
  generate_snapshot
  generate_maintenance_status
  echo "Monthly maintenance complete."
}

cmd_finish() {
  local summary="${1:-}"
  local next_step="${2:-}"

  if [[ -z "$summary" || -z "$next_step" ]]; then
    echo "Usage: scripts/context-log.sh finish \"<summary>\" \"<next-step>\"" >&2
    exit 1
  fi

  ensure_structure
  require_active_session

  local session_file
  session_file="$(read_active_session_path)"

  cat >> "$session_file" <<EOF

## Session Summary
- $summary

## Next Step
- $next_step

- Finished At (UTC): $(now_utc)
- Status: completed
EOF

  cat > "$HANDOFF_FILE" <<EOF
# Current Handoff

- Last Updated (UTC): $(now_utc)
- Last Session File: $session_file

## What Was Done
- $summary

## Next Task
- $next_step

## Resume Checklist
- Read \`HANDOFF.md\` first.
- Read \`CODEX_RESUME.md\` second.
- Open deep-dive files only when needed.
EOF

  : > "$ACTIVE_SESSION_FILE"
  generate_snapshot
  generate_maintenance_status
  echo "Finished session and updated handoff."
}

cmd_snapshot() {
  ensure_structure
  generate_snapshot
  generate_maintenance_status
  echo "Generated snapshot: $SNAPSHOT_FILE"
}

cmd_resume() {
  ensure_structure
  generate_snapshot

  local latest_session
  latest_session="$(latest_session_file)"
  local next_task
  next_task="$(read_next_task)"

  print_resume_prompt "$next_task" "$latest_session"
}

cmd_resume_lite() {
  ensure_structure
  generate_snapshot

  local latest_session
  latest_session="$(latest_session_file)"
  local next_task
  next_task="$(read_next_task)"

  print_resume_prompt "$next_task" "$latest_session"
}

cmd_status() {
  ensure_structure
  if [[ -s "$ACTIVE_SESSION_FILE" ]]; then
    echo "Active session: $(cat "$ACTIVE_SESSION_FILE")"
  else
    echo "No active session."
  fi
}

main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    init)
      cmd_init
      ;;
    start)
      cmd_start "$@"
      ;;
    note)
      cmd_note "$*"
      ;;
    decision)
      cmd_decision "$@"
      ;;
    archive-decisions)
      cmd_archive_decisions "$@"
      ;;
    monthly)
      cmd_monthly
      ;;
    finish)
      cmd_finish "$@"
      ;;
    snapshot)
      cmd_snapshot
      ;;
    resume)
      cmd_resume
      ;;
    resume-lite)
      cmd_resume_lite
      ;;
    status)
      cmd_status
      ;;
    *)
      print_usage
      exit 1
      ;;
  esac
}

main "$@"
