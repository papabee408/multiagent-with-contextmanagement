#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/setup-ci-profile.sh [--platform <type>] [--stack <framework>] [--force]

Examples:
  bash scripts/setup-ci-profile.sh --platform web --stack nextjs
  bash scripts/setup-ci-profile.sh

This script creates or refreshes docs/context/CI_PROFILE.md.
If platform or stack is omitted, the script prompts for them and falls back to simple repo detection.
EOF
}

detect_platform() {
  if [[ -f "$ROOT_DIR/pubspec.yaml" ]]; then
    printf '%s' "mobile"
    return 0
  fi

  if [[ -f "$ROOT_DIR/ProjectSettings/ProjectVersion.txt" ]]; then
    printf '%s' "game"
    return 0
  fi

  if [[ -f "$ROOT_DIR/android/app/build.gradle" || -f "$ROOT_DIR/android/app/build.gradle.kts" || -f "$ROOT_DIR/build.gradle" || -f "$ROOT_DIR/build.gradle.kts" ]]; then
    printf '%s' "mobile"
    return 0
  fi

  if find "$ROOT_DIR" -maxdepth 2 \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) | grep -q .; then
    printf '%s' "mobile"
    return 0
  fi

  if [[ -f "$ROOT_DIR/pom.xml" || -f "$ROOT_DIR/build.gradle" || -f "$ROOT_DIR/build.gradle.kts" || -f "$ROOT_DIR/pyproject.toml" ]]; then
    printf '%s' "backend"
    return 0
  fi

  if [[ -f "$ROOT_DIR/package.json" ]]; then
    if rg -q '"fastify"|fastify|"express"|express|"nestjs"|nestjs|"koa"|koa|"hono"|hono' "$ROOT_DIR/package.json"; then
      printf '%s' "backend"
      return 0
    fi
    printf '%s' "web"
    return 0
  fi

  printf '%s' "web"
}

detect_stack() {
  if [[ -f "$ROOT_DIR/pubspec.yaml" ]]; then
    printf '%s' "flutter"
    return 0
  fi

  if [[ -f "$ROOT_DIR/ProjectSettings/ProjectVersion.txt" ]]; then
    printf '%s' "unity"
    return 0
  fi

  if [[ -f "$ROOT_DIR/package.json" ]]; then
    if rg -q '"next"|next' "$ROOT_DIR/package.json"; then
      printf '%s' "nextjs"
      return 0
    fi
    if rg -q '"expo"|expo' "$ROOT_DIR/package.json"; then
      printf '%s' "expo"
      return 0
    fi
    if rg -q '"react-native"|react-native' "$ROOT_DIR/package.json"; then
      printf '%s' "react-native"
      return 0
    fi
    if [[ -f "$ROOT_DIR/vite.config.ts" || -f "$ROOT_DIR/vite.config.js" || -f "$ROOT_DIR/vite.config.mjs" ]]; then
      printf '%s' "vite"
      return 0
    fi
    if rg -q '"fastify"|fastify|"express"|express|"nestjs"|nestjs' "$ROOT_DIR/package.json"; then
      printf '%s' "node-backend"
      return 0
    fi
    printf '%s' "node"
    return 0
  fi

  if [[ -f "$ROOT_DIR/pom.xml" ]]; then
    if rg -q 'spring-boot|springframework' "$ROOT_DIR/pom.xml"; then
      printf '%s' "spring"
      return 0
    fi
    printf '%s' "java"
    return 0
  fi

  if [[ -f "$ROOT_DIR/pyproject.toml" ]]; then
    if rg -q 'fastapi' "$ROOT_DIR/pyproject.toml"; then
      printf '%s' "fastapi"
      return 0
    fi
    if rg -q 'django' "$ROOT_DIR/pyproject.toml"; then
      printf '%s' "django"
      return 0
    fi
    printf '%s' "python"
    return 0
  fi

  if [[ -f "$ROOT_DIR/android/app/build.gradle" || -f "$ROOT_DIR/android/app/build.gradle.kts" ]]; then
    printf '%s' "android-gradle"
    return 0
  fi

  if find "$ROOT_DIR" -maxdepth 2 \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) | grep -q .; then
    printf '%s' "ios-xcode"
    return 0
  fi

  printf '%s' "custom"
}

detect_package_manager() {
  if [[ -f "$ROOT_DIR/pnpm-lock.yaml" ]]; then
    printf '%s' "pnpm"
    return 0
  fi

  if [[ -f "$ROOT_DIR/yarn.lock" ]]; then
    printf '%s' "yarn"
    return 0
  fi

  if [[ -f "$ROOT_DIR/bun.lockb" || -f "$ROOT_DIR/bun.lock" ]]; then
    printf '%s' "bun"
    return 0
  fi

  if [[ -f "$ROOT_DIR/package.json" ]]; then
    printf '%s' "npm"
    return 0
  fi

  printf '%s' "none"
}

package_manager_run_prefix() {
  case "${PACKAGE_MANAGER:-none}" in
    npm)
      printf '%s' "npm run"
      ;;
    pnpm)
      printf '%s' "pnpm"
      ;;
    yarn)
      printf '%s' "yarn"
      ;;
    bun)
      printf '%s' "bun run"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

package_json_has_script() {
  local script_name="$1"

  [[ -f "$ROOT_DIR/package.json" ]] || return 1
  rg -q "\"$script_name\"[[:space:]]*:" "$ROOT_DIR/package.json"
}

array_contains() {
  local array_name="$1"
  local target="$2"
  local item

  eval 'for item in "${'"$array_name"'[@]-}"; do
    if [[ "$item" == "'"$target"'" ]]; then
      return 0
    fi
  done'

  return 1
}

append_unique() {
  local array_name="$1"
  local value="$2"

  [[ -n "$value" ]] || return 0
  if array_contains "$array_name" "$value"; then
    return 0
  fi

  eval "$array_name+=(\"\$value\")"
}

append_node_script_if_present() {
  local array_name="$1"
  local script_name="$2"
  local prefix

  prefix="$(package_manager_run_prefix)"
  [[ -n "$prefix" ]] || return 0

  if package_json_has_script "$script_name"; then
    append_unique "$array_name" "$prefix $script_name"
  fi
}

add_default_note() {
  append_unique notes "$1"
}

build_recommendations() {
  case "$PLATFORM" in
    web)
      append_node_script_if_present pr_fast_commands lint
      append_node_script_if_present pr_fast_commands typecheck
      append_node_script_if_present pr_fast_commands test
      append_node_script_if_present pr_fast_commands test:unit
      append_node_script_if_present high_risk_commands test:integration
      append_node_script_if_present high_risk_commands test:e2e
      append_node_script_if_present full_commands build
      append_node_script_if_present full_commands test
      append_node_script_if_present full_commands test:e2e
      add_default_note "Web projects usually keep PR checks fast and reserve full production builds or heavy e2e runs for manual full checks."
      ;;
    backend)
      append_node_script_if_present pr_fast_commands lint
      append_node_script_if_present pr_fast_commands typecheck
      append_node_script_if_present pr_fast_commands test
      append_node_script_if_present high_risk_commands test:integration
      append_node_script_if_present full_commands build
      append_node_script_if_present full_commands test
      if [[ -f "$ROOT_DIR/pyproject.toml" || -f "$ROOT_DIR/pytest.ini" || -d "$ROOT_DIR/tests" ]]; then
        append_unique pr_fast_commands "pytest -q"
        append_unique high_risk_commands "pytest -q"
        append_unique full_commands "pytest -q"
      fi
      if [[ -f "$ROOT_DIR/gradlew" ]]; then
        append_unique pr_fast_commands "./gradlew test"
        append_unique full_commands "./gradlew build"
      fi
      if [[ -f "$ROOT_DIR/mvnw" ]]; then
        append_unique pr_fast_commands "./mvnw test"
        append_unique full_commands "./mvnw verify"
      fi
      add_default_note "Backend full checks usually include the heaviest integration suite and the real build/package step."
      ;;
    mobile)
      case "$STACK" in
        flutter)
          append_unique pr_fast_commands "flutter analyze"
          append_unique pr_fast_commands "flutter test"
          append_unique full_commands "flutter build apk --debug"
          add_default_note "Review the Flutter full-build target if the repository ships iOS only or uses flavors."
          ;;
        android-gradle)
          if [[ -f "$ROOT_DIR/gradlew" ]]; then
            append_unique pr_fast_commands "./gradlew test"
            append_unique high_risk_commands "./gradlew lint"
            append_unique full_commands "./gradlew assembleDebug"
          else
            add_default_note "Android Gradle project detected but ./gradlew was not found. Add the real gradle commands manually."
          fi
          ;;
        expo|react-native)
          append_node_script_if_present pr_fast_commands lint
          append_node_script_if_present pr_fast_commands test
          append_node_script_if_present high_risk_commands test:e2e
          append_node_script_if_present full_commands android
          append_node_script_if_present full_commands ios
          add_default_note "React Native and Expo repos often need repo-specific device or simulator commands. Review the generated defaults."
          ;;
        ios-xcode)
          if [[ -f "$ROOT_DIR/Package.swift" ]]; then
            append_unique pr_fast_commands "swift test"
          fi
          add_default_note "iOS Xcode builds need a real scheme and destination. Fill the full checks manually after setup."
          ;;
        *)
          append_node_script_if_present pr_fast_commands lint
          append_node_script_if_present pr_fast_commands test
          add_default_note "Mobile project detected but stack-specific full build commands still need review."
          ;;
      esac
      ;;
    game)
      case "$STACK" in
        unity)
          add_default_note "Unity projects usually need a repo-specific batchmode build command. Add it after project setup."
          ;;
        *)
          add_default_note "Game projects often need engine-specific CI. Add the actual build/test entrypoints here."
          ;;
      esac
      ;;
    *)
      append_node_script_if_present pr_fast_commands lint
      append_node_script_if_present pr_fast_commands typecheck
      append_node_script_if_present pr_fast_commands test
      append_node_script_if_present full_commands build
      append_node_script_if_present full_commands test
      add_default_note "No strong preset matched. Review this file and replace the defaults with real project commands."
      ;;
  esac

  if [[ ${#pr_fast_commands[@]} -eq 0 ]]; then
    add_default_note "No fast PR commands were inferred automatically. Add the fastest reliable lint/typecheck/test commands for this repository."
  fi

  if [[ ${#full_commands[@]} -eq 0 ]]; then
    add_default_note "No full-project commands were inferred automatically. Add the slow build/regression commands you want available for manual runs."
  fi
}

prompt_with_default() {
  local prompt="$1"
  local default_value="$2"
  local answer

  if [[ -n "$default_value" ]]; then
    printf '%s [%s]: ' "$prompt" "$default_value" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  read -r answer
  answer="$(trim "$answer")"
  if [[ -n "$answer" ]]; then
    printf '%s' "$answer"
    return 0
  fi
  printf '%s' "$default_value"
}

write_section() {
  local title="$1"
  local array_name="$2"
  local fallback="$3"
  local command
  local count

  printf '%s\n' "$title"
  eval 'count=${#'"$array_name"'[@]}'
  if [[ "$count" -eq 0 ]]; then
    printf '%s\n' "$fallback"
    printf '\n'
    return 0
  fi

  eval 'for command in "${'"$array_name"'[@]}"; do
    printf -- "- `%s`\n" "$command"
  done'
  printf '\n'
}

write_notes_section() {
  local note

  printf '## Notes\n'
  if [[ ${#notes[@]} -eq 0 ]]; then
    printf '%s\n' "- Review the generated commands before turning them into required CI checks."
    return 0
  fi

  for note in "${notes[@]}"; do
    printf '%s\n' "- $note"
  done
}

PLATFORM=""
STACK=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --stack)
      STACK="$(lower "$(trim "${2:-}")")"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

PROFILE_PATH="$(ci_profile_file)"
if [[ -f "$PROFILE_PATH" && "$FORCE" -ne 1 ]]; then
  if ! grep -q "<replace>" "$PROFILE_PATH"; then
    echo "[ERROR] CI profile already exists. Use --force to overwrite it." >&2
    exit 1
  fi
fi

DEFAULT_PLATFORM="$(detect_platform)"
DEFAULT_STACK="$(detect_stack)"
PACKAGE_MANAGER="$(detect_package_manager)"

if [[ -z "$PLATFORM" ]]; then
  PLATFORM="$(prompt_with_default "Project platform (web/mobile/backend/game)" "$DEFAULT_PLATFORM")"
fi
if [[ -z "$STACK" ]]; then
  STACK="$(prompt_with_default "Framework or stack" "$DEFAULT_STACK")"
fi

PLATFORM="$(lower "$PLATFORM")"
STACK="$(lower "$STACK")"

pr_fast_commands=()
high_risk_commands=()
full_commands=()
notes=()

build_recommendations

mkdir -p "$(dirname "$PROFILE_PATH")"
cat > "$PROFILE_PATH" <<EOF
# CI Profile

## Project Profile
- platform: $PLATFORM
- stack: $STACK
- package-manager: $PACKAGE_MANAGER
- setup-status: generated

## Git / PR Policy
- git-host: github
- default-base-branch: main
- default-branch-strategy: publish-late
- task-branch-pattern: task/<task-id>
- required-check-resolution: branch-protection-first
- merge-method: squash

## Required Check Fallback
- \`AI Gate\`

EOF

write_section "## PR Fast Checks" pr_fast_commands "Add one backticked command per bullet after setup. Keep this list fast." >> "$PROFILE_PATH"
write_section "## High-Risk Checks" high_risk_commands "Add extra backticked commands only for sensitive changes that need them." >> "$PROFILE_PATH"
write_section "## Full Project Checks" full_commands "Add slower backticked commands for manual or scheduled full validation." >> "$PROFILE_PATH"
write_notes_section >> "$PROFILE_PATH"

echo "[PASS] wrote $PROFILE_PATH"
