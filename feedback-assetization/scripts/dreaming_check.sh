#!/usr/bin/env bash

set -u

hubs_file="${HOME}/.agents/hubs.md"
pwd_path="$(pwd -P)"

[[ -r "$hubs_file" ]] || exit 0

path_has_prefix() {
  local path="$1"
  local prefix="$2"

  [[ "$prefix" == "/" ]] || prefix="${prefix%/}"
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
default_hub=""
hub_path=""
in_hub_list=0
path_line_re='^- パス: `([^`]*)`'
scope_line_re='^- 作業フォルダスコープ: `([^`]*)`'

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "## ハブ一覧" ]]; then
    in_hub_list=1
    continue
  fi

  if (( in_hub_list )) && [[ "$line" == "## "* ]]; then
    break
  fi

  (( in_hub_list )) || continue

  [[ "$line" == "### "* ]] && hub_path=""

  if [[ "$line" =~ $path_line_re ]]; then
    hub_path="$(expand_home "${BASH_REMATCH[1]}")"
    if path_has_prefix "$pwd_path" "$hub_path"; then
      matched_hub="$hub_path"
    fi
    continue
  fi

  if [[ "$line" == "- 作業フォルダスコープ: "* && -n "$hub_path" ]]; then
    scope_value="${line#"- 作業フォルダスコープ: "}"
    if [[ "$scope_value" == 既定ハブ* ]]; then
      default_hub="$hub_path"
    elif [[ "$line" =~ $scope_line_re ]]; then
      scope_path="$(expand_home "${BASH_REMATCH[1]}")"
      if path_has_prefix "$pwd_path" "$scope_path"; then
        matched_hub="$hub_path"
      fi
    fi
  fi
done < "$hubs_file"

[[ -n "$matched_hub" ]] || matched_hub="$default_hub"
[[ -n "$matched_hub" ]] || exit 0

branches="$(
  git -C "$matched_hub" for-each-ref --format='%(refname:short)' 'refs/remotes/*/dreaming/*' 2>/dev/null \
    | awk 'NF { if (out) out = out ", " $0; else out = $0 } END { print out }'
)"

[[ -n "$branches" ]] || exit 0

printf '未レビューの dreaming 候補ブランチがあります: %s —「dreaming候補レビューして」で開始できます\n' "$branches"
