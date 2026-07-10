#!/bin/bash
# Claude Code の Stop フックから呼ばれ、正本スキルリポジトリの変更を
# 自動コミット・プッシュする（ハブリポジトリの自動同期と同じ運用モデル）。
#
# 対象は組み込み3リポジトリのみ。レジストリ（$HOME/.agents/skills-repos.local.md)の
# 追加リポジトリは、チーム共有リポジトリやスキル以外を含む通常プロジェクトのため
# リポジトリ全体の自動コミットは行わない（手動コミットが正）。
#
# 機密ガード: 各リポジトリの lefthook + secretlint（pre-push）に依存する。
# push がブロックされた場合はコミットがローカルに残り、systemMessage で通知する。
set -u

REPOS=(
  "$HOME/ghq/github.com/maguroid/skills"
  "$HOME/ghq/github.com/maguroid/cc-skills"
  "$HOME/ghq/github.com/maguroid/codex-skills"
)

failures=()

for repo in "${REPOS[@]}"; do
  [ -d "$repo/.git" ] || continue
  # main 以外（WIPブランチ等）や detached HEAD では何もしない
  branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null) || continue
  [ "$branch" = "main" ] || continue

  if [ -n "$(git -C "$repo" status --porcelain)" ]; then
    git -C "$repo" add -A
    if ! git -C "$repo" commit -q -m "chore: スキル自動同期 ($(date '+%Y-%m-%d %H:%M'))"; then
      failures+=("$(basename "$repo"): commit 失敗")
      continue
    fi
  fi

  # 未プッシュコミットがあれば push（過去に secretlint でブロックされた分も拾う）
  if [ -n "$(git -C "$repo" rev-list -1 '@{u}..HEAD' 2>/dev/null)" ]; then
    if ! out=$(git -C "$repo" push 2>&1); then
      short=$(printf '%s' "$out" | tail -n 3 | tr '\n' ' ')
      failures+=("$(basename "$repo"): push 失敗（secretlint ブロックの可能性）: $short")
    fi
  fi
done

if [ ${#failures[@]} -gt 0 ]; then
  jq -n --arg msg "スキル自動同期で失敗があります: ${failures[*]}" '{systemMessage: $msg}'
fi
exit 0
