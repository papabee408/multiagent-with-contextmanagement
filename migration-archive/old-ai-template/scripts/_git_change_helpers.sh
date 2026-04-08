#!/usr/bin/env bash

git_local_changed_files() {
  local root_dir="$1"

  git -C "$root_dir" status --porcelain=v1 --untracked-files=all | awk '
    {
      path = substr($0, 4)
      if (index(path, " -> ") > 0) {
        split(path, parts, " -> ")
        path = parts[length(parts)]
      }
      gsub(/^"/, "", path)
      gsub(/"$/, "", path)
      if (path != "") {
        print path
      }
    }
  ' | sed '/^$/d' | sort -u
}

git_changed_files_for_repo() {
  local root_dir="$1"
  local range="${2:-}"
  local github_base_ref="${3:-}"

  if [[ -n "$range" ]]; then
    git -C "$root_dir" diff --name-only --relative "$range"
    return 0
  fi

  if [[ -n "$github_base_ref" ]]; then
    local base_ref="origin/${github_base_ref}"
    if git -C "$root_dir" show-ref --verify --quiet "refs/remotes/${base_ref}"; then
      git -C "$root_dir" diff --name-only --relative "${base_ref}...HEAD"
      return 0
    fi
  fi

  git_local_changed_files "$root_dir"
}
