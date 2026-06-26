#!/usr/bin/env bash
# Resolve a usable Claude Agent SDK type-definition file and print its path.
#
# The skill does NOT vendor the types (they release too often). This script
# returns the authoritative copy for the task:
#   1. a project's installed node_modules copy (walking up from --dir), else
#   2. a downloaded copy of the requested version (default: latest), cached
#      under the skill's .cache/ so repeat calls are cheap.
#
# Usage:
#   scripts/find-sdk-types.sh [VERSION]        # print path to sdk.d.ts
#   scripts/find-sdk-types.sh --tools [VERSION]# print path to sdk-tools.d.ts
#   scripts/find-sdk-types.sh --dir DIR [...]  # start the install search at DIR
#
# Notes:
#   - Prints the resolved path to stdout (and only that), so `DTS=$(...)` works.
#   - Diagnostics go to stderr.
#   - Step 2 needs npm + network. If neither an install nor a fetch is possible,
#     prints guidance to stderr and exits 1.

set -euo pipefail

file="sdk.d.ts"
version=""
start_dir="$PWD"

while [ $# -gt 0 ]; do
  case "$1" in
    --tools) file="sdk-tools.d.ts"; shift ;;
    --dir)   start_dir="${2:?--dir needs a path}"; shift 2 ;;
    -*)      echo "unknown flag: $1" >&2; exit 2 ;;
    *)       version="$1"; shift ;;
  esac
done

pkg_rel="node_modules/@anthropic-ai/claude-agent-sdk"

# 1) Installed copy: walk up from start_dir.
dir="$(cd "$start_dir" && pwd)"
while :; do
  if [ -f "$dir/$pkg_rel/$file" ]; then
    if [ -z "$version" ]; then
      echo "using project install: $dir/$pkg_rel ($file)" >&2
      echo "$dir/$pkg_rel/$file"
      exit 0
    fi
    # A version was explicitly requested; only use the install if it matches.
    inst="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      "$dir/$pkg_rel/package.json" 2>/dev/null | head -1)"
    if [ "$inst" = "$version" ]; then
      echo "using project install: $dir/$pkg_rel (v$inst)" >&2
      echo "$dir/$pkg_rel/$file"
      exit 0
    fi
    break  # install exists but wrong version -> fall through to fetch
  fi
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done

# 2) Fetch into the skill's cache.
skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
spec="@anthropic-ai/claude-agent-sdk${version:+@$version}"

command -v npm >/dev/null 2>&1 || {
  echo "No installed copy found and npm is unavailable." >&2
  echo "Install it (npm i @anthropic-ai/claude-agent-sdk) or fetch manually —" >&2
  echo "see reference/getting-the-types.md." >&2
  exit 1
}

resolved="${version:-$(npm view "$spec" version 2>/dev/null || true)}"
[ -n "$resolved" ] || { echo "could not resolve a version for $spec" >&2; exit 1; }

cache="$skill_dir/.cache/$resolved"
if [ ! -f "$cache/$file" ]; then
  echo "fetching $spec (v$resolved) -> $cache" >&2
  mkdir -p "$cache"
  tmp="$(mktemp -d)"
  ( cd "$tmp" && npm pack "@anthropic-ai/claude-agent-sdk@$resolved" >/dev/null 2>&1 \
      && tar -xzf anthropic-ai-claude-agent-sdk-*.tgz )
  cp "$tmp/package/sdk.d.ts" "$tmp/package/sdk-tools.d.ts" "$cache/" 2>/dev/null || true
  rm -rf "$tmp"
fi

[ -f "$cache/$file" ] || { echo "fetch failed for $file" >&2; exit 1; }
echo "$cache/$file"
