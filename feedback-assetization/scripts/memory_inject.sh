#!/usr/bin/env bash

set -u

hubs_file="${HOME}/.agents/hubs.md"
pwd_path="${PWD}"

[[ -r "$hubs_file" ]] || exit 0

path_has_prefix() {
  local path="$1"
  local prefix="$2"

  [[ "$path" == "$prefix" || "$path" == "$prefix"/* ]]
}

expand_home() {
  local path="$1"

  if [[ "$path" == "~" ]]; then
    printf '%s\n' "$HOME"
  elif [[ "$path" == "~/"* ]]; then
    printf '%s/%s\n' "$HOME" "${path#"~/"}"
  else
    printf '%s\n' "$path"
  fi
}

matched_hub=""
in_hub_list=0
in_hub_section=0
path_line_re='^- パス: `(~[^`]*)`'

while IFS= read -r line; do
  if [[ "$line" == "## ハブ一覧" ]]; then
    in_hub_list=1
    in_hub_section=0
    continue
  fi

  if (( in_hub_list )) && [[ "$line" == "## "* ]]; then
    break
  fi

  (( in_hub_list )) || continue

  if [[ "$line" == "### "* ]]; then
    in_hub_section=1
    continue
  fi

  (( in_hub_section )) || continue

  if [[ "$line" =~ $path_line_re ]]; then
    hub_path="$(expand_home "${BASH_REMATCH[1]}")"
    if path_has_prefix "$pwd_path" "$hub_path"; then
      matched_hub="$hub_path"
      break
    fi
  fi
done < "$hubs_file"

[[ -n "$matched_hub" ]] || exit 0

memory_file="${matched_hub}/agent-memory/MEMORY.md"
[[ -r "$memory_file" ]] || exit 0

printf '# ハブのエージェントメモリ索引（agent-memory/MEMORY.md）\n'
printf '関連するメモリ本文は %s/agent-memory/ 配下を Read すること。\n' "$matched_hub"
cat "$memory_file"
