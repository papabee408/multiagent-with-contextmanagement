#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/_run_log_helpers.sh"

FEATURE_ID=""

usage() {
  cat <<'EOF'
Usage:
  scripts/implementer-subtasks.sh mode [--feature <feature-id>]
  scripts/implementer-subtasks.sh list [--feature <feature-id>]
  scripts/implementer-subtasks.sh validate [--feature <feature-id>]
EOF
}

COMMAND="${1:-}"
if [[ -z "$COMMAND" ]]; then
  usage
  exit 1
fi
shift || true

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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unexpected argument: $1" >&2
      exit 1
      ;;
  esac
done

FEATURE_ID="$(resolve_feature_id_or_exit "$FEATURE_ID")"
source "$ROOT_DIR/scripts/gates/_helpers.sh" "$FEATURE_ID"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "[ERROR] plan file not found: $PLAN_FILE" >&2
  exit 1
fi

PLAN_FILE_ENV="$PLAN_FILE" COMMAND_ENV="$COMMAND" node <<'EOF'
const fs = require("fs");

const file = process.env.PLAN_FILE_ENV;
const command = process.env.COMMAND_ENV;
const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);

const extractPaths = (text) => {
  const matches = [...String(text || "").matchAll(/`([^`]+)`/g)];
  return matches.map((match) => match[1].trim()).filter(Boolean);
};

const cleanNestedValue = (line) =>
  line
    .replace(/^[\s-]+/, "")
    .trim();

const unique = (values) => [...new Set(values.filter(Boolean))];

const sectionValue = (sectionTitle, key) => {
  let inSection = false;
  for (const rawLine of lines) {
    if (rawLine === sectionTitle) {
      inSection = true;
      continue;
    }
    if (inSection && rawLine.startsWith("## ")) {
      break;
    }
    if (!inSection) {
      continue;
    }
    const prefix = `- ${key}:`;
    if (rawLine.startsWith(prefix)) {
      return rawLine.slice(prefix.length).replace(/`/g, "").trim();
    }
  }
  return "";
};

const parseExecutionStrategy = () => {
  const data = {
    implementer_mode: sectionValue("## Execution Strategy", "implementer mode") || "serial",
    merge_owner: sectionValue("## Execution Strategy", "merge owner"),
    shared_files: [],
  };

  let inSection = false;
  let inSharedFiles = false;
  for (const rawLine of lines) {
    if (rawLine === "## Execution Strategy") {
      inSection = true;
      continue;
    }
    if (inSection && rawLine.startsWith("## ")) {
      break;
    }
    if (!inSection) {
      continue;
    }

    if (rawLine.startsWith("- shared files reserved for parent:")) {
      inSharedFiles = true;
      data.shared_files.push(...extractPaths(rawLine));
      continue;
    }

    if (rawLine.startsWith("- ")) {
      inSharedFiles = false;
    }

    if (inSharedFiles) {
      data.shared_files.push(...extractPaths(rawLine));
    }
  }

  data.implementer_mode = data.implementer_mode.trim().toLowerCase() || "serial";
  data.shared_files = unique(data.shared_files);
  return data;
};

const parseTaskCards = () => {
  const tasks = [];
  let inSection = false;
  let currentTask = null;
  let currentField = "";

  const flushTask = () => {
    if (!currentTask) {
      return;
    }
    currentTask.files = unique(currentTask.files);
    currentTask.change = currentTask.change.filter(Boolean).join("; ");
    currentTask.done_when = currentTask.done_when.filter(Boolean).join("; ");
    tasks.push(currentTask);
    currentTask = null;
    currentField = "";
  };

  for (const rawLine of lines) {
    if (rawLine === "## Task Cards") {
      inSection = true;
      continue;
    }
    if (inSection && rawLine.startsWith("## ")) {
      break;
    }
    if (!inSection) {
      continue;
    }

    if (rawLine.startsWith("### ")) {
      flushTask();
      currentTask = {
        title: rawLine.slice(4).trim(),
        files: [],
        change: [],
        done_when: [],
      };
      continue;
    }

    if (!currentTask) {
      continue;
    }

    if (rawLine.startsWith("- files:")) {
      currentField = "files";
      currentTask.files.push(...extractPaths(rawLine));
      continue;
    }

    if (rawLine.startsWith("- change:")) {
      currentField = "change";
      const value = cleanNestedValue(rawLine.slice("- change:".length));
      if (value) {
        currentTask.change.push(value);
      }
      continue;
    }

    if (rawLine.startsWith("- done when:")) {
      currentField = "done_when";
      const value = cleanNestedValue(rawLine.slice("- done when:".length));
      if (value) {
        currentTask.done_when.push(value);
      }
      continue;
    }

    if (!rawLine.trim()) {
      continue;
    }

    if (currentField === "files") {
      currentTask.files.push(...extractPaths(rawLine));
      continue;
    }

    if (currentField === "change") {
      currentTask.change.push(cleanNestedValue(rawLine));
      continue;
    }

    if (currentField === "done_when") {
      currentTask.done_when.push(cleanNestedValue(rawLine));
    }
  }

  flushTask();
  return tasks;
};

const execution = parseExecutionStrategy();
const tasks = parseTaskCards();

if (command === "mode") {
  process.stdout.write(`${execution.implementer_mode}\n`);
  process.exit(0);
}

if (command === "list") {
  process.stdout.write(`implementer-mode: ${execution.implementer_mode}\n`);
  process.stdout.write(`merge-owner: ${execution.merge_owner || "TBD"}\n`);
  process.stdout.write(
    `shared-files: ${execution.shared_files.length > 0 ? execution.shared_files.join(", ") : "none"}\n`,
  );
  process.stdout.write(`task-card-count: ${tasks.length}\n`);
  for (const task of tasks) {
    const files = task.files.length > 0 ? task.files.join(", ") : "none";
    process.stdout.write(`- ${task.title}: ${files}\n`);
  }
  process.exit(0);
}

if (command !== "validate") {
  process.stderr.write(`Unsupported command: ${command}\n`);
  process.exit(1);
}

const failures = [];

if (!["serial", "parallel"].includes(execution.implementer_mode)) {
  failures.push(`invalid-implementer-mode(${execution.implementer_mode})`);
}

if (execution.implementer_mode === "parallel") {
  if ((execution.merge_owner || "").trim().toLowerCase() !== "implementer") {
    failures.push("parallel-mode-requires-merge-owner-implementer");
  }
  if (tasks.length < 2) {
    failures.push("parallel-mode-requires-at-least-two-task-cards");
  }

  const seenFiles = new Map();
  const seenSharedFiles = new Set();

  for (const sharedFile of execution.shared_files) {
    if (seenSharedFiles.has(sharedFile)) {
      failures.push(`duplicate-shared-file(${sharedFile})`);
      continue;
    }
    seenSharedFiles.add(sharedFile);
  }

  for (const task of tasks) {
    if (task.files.length === 0) {
      failures.push(`task-card-missing-files(${task.title})`);
      continue;
    }

    for (const filePath of task.files) {
      if (seenSharedFiles.has(filePath)) {
        failures.push(`shared-file-overlaps-task(${filePath}:${task.title})`);
      }
      if (seenFiles.has(filePath)) {
        failures.push(`duplicate-task-file(${filePath}:${seenFiles.get(filePath)},${task.title})`);
        continue;
      }
      seenFiles.set(filePath, task.title);
    }
  }
}

if (failures.length > 0) {
  process.stdout.write("[FAIL] implementer-subtasks\n");
  for (const failure of failures) {
    process.stdout.write(` - ${failure}\n`);
  }
  process.exit(1);
}

process.stdout.write("[PASS] implementer-subtasks\n");
process.stdout.write(` - mode: ${execution.implementer_mode}\n`);
process.stdout.write(` - task-cards: ${tasks.length}\n`);
EOF
