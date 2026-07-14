#!/usr/bin/env bash
set -euo pipefail

REGISTRY_FILE="$HOME/.agents/workspace-skills.local.md"
CHEZMOI_REGISTRY_FILE="$HOME/.local/share/chezmoi/dot_agents/workspace-skills.local.md"

workspace_names=()
workspace_roots=()
workspace_skill_dirs=()

linked_created=0
already_correct=0
conflicts=0
strays=0
failures=0

conflict_items=()
stray_items=()

warn() {
  printf 'warning: %s\n' "$*" >&2
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

add_workspace() {
  local name=$1
  local root=$2
  local skills=$3
  local i

  root=$(expand_home_path "$root")
  skills=$(expand_home_path "$skills")

  for ((i = 0; i < ${#workspace_roots[@]}; i += 1)); do
    if [ "${workspace_roots[$i]}" = "$root" ] && [ "${workspace_skill_dirs[$i]}" = "$skills" ]; then
      return
    fi
  done

  workspace_names+=("$name")
  workspace_roots+=("$root")
  workspace_skill_dirs+=("$skills")
}

pending_name=""
pending_root=""
pending_skills=""

flush_registry_entry() {
  if [ -n "$pending_root" ] && [ -n "$pending_skills" ]; then
    add_workspace "${pending_name:-unnamed}" "$pending_root" "$pending_skills"
  elif [ -n "$pending_root" ] || [ -n "$pending_skills" ]; then
    warn "skipping incomplete workspace entry: name='$pending_name' root='$pending_root' skills='$pending_skills'"
  fi

  pending_name=""
  pending_root=""
  pending_skills=""
}

read_registry_file() {
  local file=$1
  local line

  [ -f "$file" ] || return

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '### '*)
        flush_registry_entry
        pending_name="${line#"### "}"
        ;;
      '- Root: `'* | '- ルート: `'* )
        pending_root=$(extract_backtick_value "$line")
        ;;
      '- Skills: `'* | '- スキル正本: `'* )
        pending_skills=$(extract_backtick_value "$line")
        ;;
    esac
  done < "$file"

  flush_registry_entry
}

record_conflict() {
  conflicts=$((conflicts + 1))
  conflict_items+=("$1 ($2)")
}

record_stray() {
  strays=$((strays + 1))
  stray_items+=("$1 ($2)")
}

reconcile_link() {
  local canonical=$1
  local link=$2
  local target

  if [ -L "$link" ]; then
    target=$(readlink "$link")
    if [ "$target" = "$canonical" ]; then
      already_correct=$((already_correct + 1))
    else
      record_conflict "$link" "symlink target is $target"
    fi
  elif [ -e "$link" ]; then
    record_conflict "$link" "existing non-symlink entry"
  elif ln -s "$canonical" "$link"; then
    linked_created=$((linked_created + 1))
  else
    warn "failed to create symlink: $link -> $canonical"
    failures=$((failures + 1))
  fi
}

check_strays() {
  local discovery_dir=$1
  local canonical_root=$2
  local link
  local target

  shopt -s nullglob
  for link in "$discovery_dir"/*; do
    [ -L "$link" ] || continue
    target=$(readlink "$link")
    case "$target" in
      "$canonical_root"/*)
        if [ ! -e "$link" ]; then
          record_stray "$link" "workspace skill no longer exists; left untouched"
        fi
        ;;
    esac
  done
  shopt -u nullglob
}

process_workspace() {
  local name=$1
  local root=$2
  local skills=$3
  local agents_dir="$root/.agents/skills"
  local claude_dir="$root/.claude/skills"
  local skill_md
  local canonical
  local skill_name

  printf 'workspace: %s\n' "$name"

  if [ ! -d "$root" ]; then
    warn "$name: workspace root is missing: $root"
    failures=$((failures + 1))
    return
  fi

  if [ ! -d "$skills" ]; then
    warn "$name: canonical skills directory is missing: $skills"
    failures=$((failures + 1))
    return
  fi

  if ! mkdir -p "$agents_dir" "$claude_dir"; then
    warn "$name: failed to create discovery directories under $root"
    failures=$((failures + 1))
    return
  fi

  while IFS= read -r skill_md; do
    canonical=$(dirname "$skill_md")
    skill_name=$(basename "$canonical")
    reconcile_link "$canonical" "$agents_dir/$skill_name"
    reconcile_link "$canonical" "$claude_dir/$skill_name"
  done < <(find "$skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -print | sort)

  check_strays "$agents_dir" "$skills"
  check_strays "$claude_dir" "$skills"
}

print_summary() {
  local item

  printf '\nWorkspace skill projection summary:\n'
  printf '  workspaces: %d\n' "${#workspace_roots[@]}"
  printf '  linked(created): %d\n' "$linked_created"
  printf '  already-correct: %d\n' "$already_correct"
  printf '  conflicts: %d\n' "$conflicts"
  printf '  strays: %d\n' "$strays"
  printf '  failures: %d\n' "$failures"

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

  read_registry_file "$REGISTRY_FILE"
  read_registry_file "$CHEZMOI_REGISTRY_FILE"

  if [ "${#workspace_roots[@]}" -eq 0 ]; then
    warn "no workspace skill projections registered"
    print_summary
    return 0
  fi

  printf 'Workspace-local skill projection\n'
  for ((i = 0; i < ${#workspace_roots[@]}; i += 1)); do
    process_workspace "${workspace_names[$i]}" "${workspace_roots[$i]}" "${workspace_skill_dirs[$i]}"
  done

  print_summary
  [ "$failures" -eq 0 ]
}

main "$@"
