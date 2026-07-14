#!/usr/bin/env bash
set -euo pipefail

REGISTRY_FILE="$HOME/.agents/skills-repos.local.md"
CHEZMOI_REGISTRY_FILE="$HOME/.local/share/chezmoi/dot_agents/skills-repos.local.md"
AGENTS_DIR="$HOME/.agents/skills"
CLAUDE_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.codex/skills"

repo_paths=()
repo_githubs=()
repo_schemes=()
repo_skills_paths=()
repo_sources=()

cloned=0
pulled=0
pull_skipped_dirty=0
pull_failures=0
linked_created=0
repaired=0
already_correct=0
conflicts=0
strays=0
clone_failures=0
registry_clone_failures=0
link_failures=0
hooks_installed=0
hooks_skipped=0

conflict_items=()
stray_items=()

warn() {
  printf 'warning: %s\n' "$*" >&2
}

add_repo() {
  local path=$1
  local github=$2
  local scheme=$3
  local skills_path=$4
  local source=$5
  local i

  case "$scheme" in
    agent-neutral | claude-only | codex-only | workspace-only) ;;
    *) scheme="agent-neutral" ;;
  esac

  for ((i = 0; i < ${#repo_paths[@]}; i += 1)); do
    if [ "${repo_paths[$i]}" = "$path" ]; then
      return
    fi
  done

  repo_paths+=("$path")
  repo_githubs+=("$github")
  repo_schemes+=("$scheme")
  repo_skills_paths+=("$skills_path")
  repo_sources+=("$source")
}

extract_backtick_value() {
  local line=$1
  local value
  value=${line#*\`}
  printf '%s\n' "${value%%\`*}"
}

expand_home_path() {
  local path=$1

  case "$path" in
    '$HOME'*)
      printf '%s%s\n' "$HOME" "${path#\$HOME}"
      ;;
    '~/'*)
      printf '%s/%s\n' "$HOME" "${path#~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

pending_path=""
pending_github=""
pending_scheme="agent-neutral"
pending_skills_path=""

flush_registry_entry() {
  local expanded_path

  if [ -n "$pending_path" ] && [ -n "$pending_github" ]; then
    expanded_path=$(expand_home_path "$pending_path")
    add_repo "$expanded_path" "$pending_github" "$pending_scheme" "$pending_skills_path" "registry"
  elif [ -n "$pending_path" ] || [ -n "$pending_github" ]; then
    warn "skipping incomplete registry entry: path='$pending_path' github='$pending_github'"
  fi

  pending_path=""
  pending_github=""
  pending_scheme="agent-neutral"
  pending_skills_path=""
}

read_registry_file() {
  local file=$1
  local line

  if [ ! -f "$file" ]; then
    return
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '### '*)
        flush_registry_entry
        ;;
      '- Path: `'*)
        pending_path=$(extract_backtick_value "$line")
        ;;
      '- GitHub: `'*)
        pending_github=$(extract_backtick_value "$line")
        ;;
      '- Skills path: `'*)
        pending_skills_path=$(extract_backtick_value "$line")
        ;;
      '- Symlink scheme:'*)
        case "$line" in
          *workspace-only*)
            pending_scheme="workspace-only"
            ;;
          *codex-only*)
            pending_scheme="codex-only"
            ;;
          *claude-only*)
            pending_scheme="claude-only"
            ;;
          *)
            pending_scheme="agent-neutral"
            ;;
        esac
        ;;
    esac
  done < "$file"

  flush_registry_entry
}

read_registries() {
  read_registry_file "$REGISTRY_FILE"
  read_registry_file "$CHEZMOI_REGISTRY_FILE"
}

record_conflict() {
  local link=$1
  local detail=$2

  conflicts=$((conflicts + 1))
  conflict_items+=("$link ($detail)")
}

record_stray() {
  local link=$1
  local detail=$2

  strays=$((strays + 1))
  stray_items+=("$link ($detail)")
}

record_stray_link() {
  local link=$1
  local canonical=$2
  local detail=$3
  local target

  if [ -L "$link" ]; then
    target=$(readlink "$link")
    if [ "$target" = "$canonical" ]; then
      record_stray "$link" "$detail"
    fi
  fi
}

reconcile_link() {
  local canonical=$1
  local link=$2
  local target

  if [ -L "$link" ]; then
    target=$(readlink "$link")
    if [ "$target" = "$canonical" ]; then
      if [ -e "$link" ]; then
        already_correct=$((already_correct + 1))
      elif ln -sfn "$canonical" "$link"; then
        repaired=$((repaired + 1))
      else
        warn "failed to repair symlink: $link -> $canonical"
        link_failures=$((link_failures + 1))
      fi
    else
      record_conflict "$link" "symlink target is $target"
    fi
  elif [ -e "$link" ]; then
    record_conflict "$link" "existing non-symlink entry"
  elif ln -s "$canonical" "$link"; then
    linked_created=$((linked_created + 1))
  else
    warn "failed to create symlink: $link -> $canonical"
    link_failures=$((link_failures + 1))
  fi
}

clone_if_missing() {
  local repo_path=$1
  local github=$2
  local source=$3
  local clone_url="git@github.com:${github}.git"
  local parent

  if [ -d "$repo_path" ]; then
    return 0
  fi

  if [ -e "$repo_path" ]; then
    warn "repo path exists but is not a directory: $repo_path"
    if [ "$source" = "registry" ]; then
      registry_clone_failures=$((registry_clone_failures + 1))
    else
      clone_failures=$((clone_failures + 1))
    fi
    return 1
  fi

  parent=${repo_path%/*}
  if ! mkdir -p "$parent"; then
    warn "failed to create parent directory: $parent"
    if [ "$source" = "registry" ]; then
      registry_clone_failures=$((registry_clone_failures + 1))
    else
      clone_failures=$((clone_failures + 1))
    fi
    return 1
  fi

  if git clone "$clone_url" "$repo_path"; then
    cloned=$((cloned + 1))
    return 0
  fi

  warn "failed to clone $clone_url into $repo_path"
  if [ "$source" = "registry" ]; then
    registry_clone_failures=$((registry_clone_failures + 1))
  else
    clone_failures=$((clone_failures + 1))
  fi
  return 1
}

pull_if_clean() {
  local repo_path=$1
  local status_output

  if ! status_output=$(git -C "$repo_path" status --porcelain 2>/dev/null); then
    warn "failed to inspect repo status; skipping pull: $repo_path"
    pull_failures=$((pull_failures + 1))
    return
  fi

  if [ -n "$status_output" ]; then
    warn "repo is dirty; skipping pull: $repo_path"
    pull_skipped_dirty=$((pull_skipped_dirty + 1))
    return
  fi

  if git -C "$repo_path" pull --ff-only; then
    pulled=$((pulled + 1))
  else
    warn "failed to pull --ff-only; continuing without updating: $repo_path"
    pull_failures=$((pull_failures + 1))
  fi
}

resolve_lefthook() {
  if command -v lefthook >/dev/null 2>&1; then
    command -v lefthook
    return 0
  fi

  if [ -x "$HOME/.local/share/mise/shims/lefthook" ]; then
    printf '%s\n' "$HOME/.local/share/mise/shims/lefthook"
    return 0
  fi

  return 1
}

resolve_npm() {
  if command -v npm >/dev/null 2>&1; then
    command -v npm
    return 0
  fi

  if [ -x "$HOME/.local/share/mise/shims/npm" ]; then
    printf '%s\n' "$HOME/.local/share/mise/shims/npm"
    return 0
  fi

  return 1
}

prepare_hook_dependencies() {
  local repo_path=$1
  local npm_cmd

  if [ -d "$repo_path/node_modules" ]; then
    return 0
  fi

  if [ ! -f "$repo_path/package.json" ] && [ ! -f "$repo_path/package-lock.json" ]; then
    return 0
  fi

  if [ ! -f "$repo_path/package.json" ] || [ ! -f "$repo_path/package-lock.json" ]; then
    warn "node_modules missing but package manifest is incomplete; skipping hook install: $repo_path"
    return 1
  fi

  if ! npm_cmd=$(resolve_npm); then
    warn "node_modules missing but npm command is unavailable; skipping hook install: $repo_path"
    return 1
  fi

  if (cd "$repo_path" && "$npm_cmd" ci --no-audit --no-fund); then
    return 0
  fi

  warn "failed to prepare hook dependencies with npm ci; skipping hook install: $repo_path"
  return 1
}

install_hooks_if_available() {
  local repo_path=$1
  local lefthook_cmd

  if [ ! -f "$repo_path/lefthook.yml" ]; then
    return
  fi

  if ! lefthook_cmd=$(resolve_lefthook); then
    warn "lefthook.yml found but lefthook command is unavailable; skipping hook install: $repo_path"
    hooks_skipped=$((hooks_skipped + 1))
    return
  fi

  if ! prepare_hook_dependencies "$repo_path"; then
    hooks_skipped=$((hooks_skipped + 1))
    return
  fi

  if (cd "$repo_path" && "$lefthook_cmd" install); then
    hooks_installed=$((hooks_installed + 1))
  else
    warn "failed to install lefthook hooks; continuing: $repo_path"
    hooks_skipped=$((hooks_skipped + 1))
  fi
}

enumerate_skills() {
  local repo_path=$1
  local skills_path=$2
  local base
  local name

  if [ "$skills_path" = "." ]; then
    if [ -f "$repo_path/SKILL.md" ]; then
      name=$(basename "$repo_path")
      printf '%s\t%s\n' "$name" "$repo_path"
    else
      warn "skills path is '.' but SKILL.md is missing: $repo_path"
    fi
    return
  fi

  if [ -n "$skills_path" ]; then
    base="$repo_path/$skills_path"
  else
    base="$repo_path"
  fi

  if [ ! -d "$base" ]; then
    warn "skills path is missing: $base"
    return
  fi

  while IFS= read -r skill_md; do
    name=$(basename "$(dirname "$skill_md")")
    printf '%s\t%s\n' "$name" "$(dirname "$skill_md")"
  done < <(find "$base" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -print | sort)
}

process_repo() {
  local repo_path=$1
  local github=$2
  local scheme=$3
  local skills_path=$4
  local source=$5
  local name
  local canonical
  local repo_existed=0

  if [ -n "$skills_path" ]; then
    printf 'repo: %s (%s, skills path: %s)\n' "$github" "$scheme" "$skills_path"
  else
    printf 'repo: %s (%s)\n' "$github" "$scheme"
  fi

  if [ -d "$repo_path" ]; then
    repo_existed=1
  fi

  if ! clone_if_missing "$repo_path" "$github" "$source"; then
    return
  fi

  if [ "$repo_existed" -eq 1 ]; then
    pull_if_clean "$repo_path"
  fi

  install_hooks_if_available "$repo_path"

  while IFS=$'\t' read -r name canonical; do
    if [ -z "$name" ] || [ -z "$canonical" ]; then
      continue
    fi

    case "$scheme" in
      agent-neutral)
        reconcile_link "$canonical" "$AGENTS_DIR/$name"
        reconcile_link "$canonical" "$CLAUDE_DIR/$name"
        ;;
      claude-only)
        record_stray_link "$AGENTS_DIR/$name" "$canonical" "claude-only skill linked into agent-neutral discovery"
        record_stray_link "$CODEX_DIR/$name" "$canonical" "claude-only skill linked into Codex discovery"
        reconcile_link "$canonical" "$CLAUDE_DIR/$name"
        ;;
      codex-only)
        record_stray_link "$AGENTS_DIR/$name" "$canonical" "codex-only skill linked into agent-neutral discovery"
        record_stray_link "$CLAUDE_DIR/$name" "$canonical" "codex-only skill linked into Claude discovery"
        reconcile_link "$canonical" "$CODEX_DIR/$name"
        ;;
      workspace-only)
        record_stray_link "$AGENTS_DIR/$name" "$canonical" "workspace-only skill linked into agent-neutral discovery"
        record_stray_link "$CLAUDE_DIR/$name" "$canonical" "workspace-only skill linked into Claude discovery"
        record_stray_link "$CODEX_DIR/$name" "$canonical" "workspace-only skill linked into Codex discovery"
        ;;
    esac
  done < <(enumerate_skills "$repo_path" "$skills_path")
}

print_summary() {
  local item

  printf '\nSummary:\n'
  printf '  cloned: %d\n' "$cloned"
  printf '  pulled: %d\n' "$pulled"
  printf '  pull skipped (dirty): %d\n' "$pull_skipped_dirty"
  printf '  pull failures: %d\n' "$pull_failures"
  printf '  linked(created): %d\n' "$linked_created"
  printf '  repaired: %d\n' "$repaired"
  printf '  already-correct: %d\n' "$already_correct"
  printf '  conflicts: %d\n' "$conflicts"
  printf '  strays: %d\n' "$strays"
  printf '  clone failures: %d\n' "$clone_failures"
  printf '  registry clone failures: %d\n' "$registry_clone_failures"
  printf '  link failures: %d\n' "$link_failures"
  printf '  hooks installed: %d\n' "$hooks_installed"
  printf '  hooks skipped: %d\n' "$hooks_skipped"

  if [ "$conflicts" -gt 0 ]; then
    printf '\nConflicts left untouched:\n'
    for item in "${conflict_items[@]}"; do
      printf '  - %s\n' "$item"
    done
  fi

  if [ "$strays" -gt 0 ]; then
    printf '\nStrays left untouched:\n'
    for item in "${stray_items[@]}"; do
      printf '  - %s\n' "$item"
    done
  fi
}

main() {
  local i

  add_repo "$HOME/ghq/github.com/maguroid/skills" "maguroid/skills" "agent-neutral" "" "builtin"
  add_repo "$HOME/ghq/github.com/maguroid/cc-skills" "maguroid/cc-skills" "claude-only" "" "builtin"
  add_repo "$HOME/ghq/github.com/maguroid/codex-skills" "maguroid/codex-skills" "codex-only" "" "builtin"
  read_registries

  if ! mkdir -p "$AGENTS_DIR" "$CLAUDE_DIR" "$CODEX_DIR"; then
    warn "failed to create discovery directories"
    link_failures=$((link_failures + 1))
    print_summary
    return 1
  fi

  printf 'Global skills bootstrap\n'
  for ((i = 0; i < ${#repo_paths[@]}; i += 1)); do
    process_repo "${repo_paths[$i]}" "${repo_githubs[$i]}" "${repo_schemes[$i]}" "${repo_skills_paths[$i]}" "${repo_sources[$i]}"
  done

  print_summary

  if [ "$clone_failures" -gt 0 ] || [ "$link_failures" -gt 0 ]; then
    return 1
  fi

  return 0
}

main "$@"
