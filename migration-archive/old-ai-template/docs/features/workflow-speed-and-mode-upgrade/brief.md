# Feature Brief

## Feature ID
- `feature-id`: workflow-speed-and-mode-upgrade

## Goal
- Replace legacy mode routing with user-owned workflow/execution mode selection and keep a faster local verification loop without weakening final approval or gate authority.
- Keep completion-generated operational files from re-dirtying the worktree right before commit, PR, or git cleanup.

## Non-goals
- Do not remove feature packets, role-chain enforcement, or the final authoritative full gate.
- Do not make multi-agent dispatch implicit when the user has not explicitly chosen it.
- Do not let AI silently change workflow or execution mode after bootstrap.

## Requirements (RQ)
- `RQ-001`: New implementation requests must start with a user-visible choice of workflow mode (`Trivial`, `Lite`, `Full`) and execution mode (`Single`, `Multi-Agent`), with AI recommendations shown first.
- `RQ-002`: Workflow mode and execution mode become locked after bootstrap and may change only when the user explicitly approves the change.
- `RQ-003`: The workflow layer must support `trivial`, `lite`, and `full`, keep the same `feature-id`, and allow only upward promotion through `promote-workflow.sh`.
- `RQ-004`: Execution mode must support both `single` and `multi-agent`; `single` may reuse one lead `agent-id` across roles and still use bounded helper sub-agents, while `multi-agent` keeps role `agent-id` values unique.
- `RQ-005`: Reviewer and security approval must bind to the current final implementation state, but closeout-only operational files must not invalidate approvals.
- `RQ-006`: Developers must have a `fast` local gate path and cheaper Git change-set collection while keeping the existing full gate authoritative for completion and CI, and a clean worktree must not be reinterpreted as the previous commit diff.
- `RQ-007`: `implementer` dispatch must stay blocked until `brief`, `plan`, and synced handoffs all pass, including `trivial` mode, so code edits do not start from a stale packet.
- `RQ-008`: `complete-feature.sh` must absorb closeout-generated packet/context changes for the active feature and the current completion session before final clean-tree, commit, or PR checks so `run-log.md` and related operational files do not cause false dirty-state warnings after completion.
- `RQ-009`: Dispatch monitor timestamps must reflect actual role start time, so `queue` may leave `started-at-utc` and `interrupt-after-utc` blank until `start` or later execution signals occur.

## Constraints
- Keep final completion on `scripts/gates/run.sh` and CI `Gates`.
- Preserve planner ownership of `plan.md`.
- Keep reviewer/security mandatory in `full` mode only.
- Reuse existing packet, handoff, receipt, and gate helper abstractions where possible.
- Do not solve dirty closeout files by ignoring tracked operational files; keep them versioned and absorb them intentionally.
- Keep workflow/execution mode changes explicit and user-approved.

## Acceptance
- workflow/execution selection guidance is documented and template prompts ask for both choices with recommendations.
- `workflow-mode.sh` and role-chain logic support `trivial`, `lite`, and `full`, and `promote-workflow.sh` only allows upward changes.
- `execution-mode.sh` exists, briefs record `single|multi-agent`, and `single` vs `multi-agent` role ownership rules are enforced by docs and gate logic.
- Reviewer/security receipts record and validate a current approval-target hash without being invalidated by closeout-only operational files.
- `scripts/gates/run.sh --fast` exists for local iteration while final completion still uses the full gate path.
- Git change-set collection is centralized so local workflows stop repeating expensive diff/status collection patterns across scripts, and clean worktrees do not silently fall back to the previous commit.
- `implementer` cannot be queued until `bash scripts/gates/check-implementer-ready.sh --feature <feature-id>` passes.
- `scripts/complete-feature.sh` stages changed closeout files for the active feature and current completion session by default, with an escape hatch for explicit opt-out.
- Dispatch monitor output keeps queued roles visibly queued without claiming a start timestamp before execution begins.

## Workflow Mode
- mode: `full`
- rationale: cross-cutting template change still needs reviewer and security verification

## Execution Mode
- mode: `single`
- rationale: one lead agent can carry the refactor end-to-end while still using bounded helper sub-agents if needed

## Requirement Notes
- External dependencies: none
- Existing modules/components/constants to reuse: workflow/execution mode helpers, gate helpers, validation cache receipts, role receipts, feature packet templates, shared Git change helpers
- Values/config that must not be hardcoded: workflow mode names, execution mode names, approval-hash field names, gate mode names, role-chain state rules
