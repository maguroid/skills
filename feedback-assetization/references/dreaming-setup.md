# dreaming 夜間ジョブ セットアップ

`feedback-assetization/scripts/dreaming_nightly.py` を launchd で毎朝 05:00 に実行し、
各ハブの `dreaming/YYYY-MM-DD` ブランチへ候補を出すための手順。

## 前提

- `$HOME/.agents/hubs.md` の `## ハブ一覧` に、各ハブの `- パス:` と
  `- 作業フォルダスコープ:` がある。
- `uv`、`git`、`tmux`、`claude` が PATH から実行できる。PR 作成まで行う場合は `gh` も
  ログイン済みにする。
- Claude Code のトランスクリプトは `$HOME/.claude/projects/*/*.jsonl` にある。

## インストール

1. テンプレートを LaunchAgents にコピーする。

   ```sh
   mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
   cp "$HOME/ghq/github.com/maguroid/skills/feedback-assetization/scripts/com.maguroid.dreaming.plist.example" \
     "$HOME/Library/LaunchAgents/com.maguroid.dreaming.plist"
   ```

2. plist 内の `__HOME__` を自分の `$HOME` に置換する。

   ```sh
   sed -i '' "s#__HOME__#$HOME#g" "$HOME/Library/LaunchAgents/com.maguroid.dreaming.plist"
   ```

3. launchd に読み込ませる。

   ```sh
   launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.maguroid.dreaming.plist"
   launchctl enable "gui/$(id -u)/com.maguroid.dreaming"
   ```

## 動作確認

まず dry-run で、ハブのルーティングとダイジェスト統計だけを確認する。これは
`$HOME/.agents/hubs.md` と `$HOME/.claude/projects` を読むが、ブランチ作成、tmux 起動、
push は行わない。

```sh
uv run --no-project "$HOME/ghq/github.com/maguroid/skills/feedback-assetization/scripts/dreaming_nightly.py" --dry-run
```

特定ハブだけ確認する場合:

```sh
uv run --no-project "$HOME/ghq/github.com/maguroid/skills/feedback-assetization/scripts/dreaming_nightly.py" --dry-run --hub "<ハブ名>"
```

`--hub` は `$HOME/.agents/hubs.md` の完全なハブ名に一致する。ハブ名が
`Workspace-Me（個人）` のように括弧付きの場合は、曖昧でなければ括弧の前まででも指定できる。

```sh
uv run --no-project "$HOME/ghq/github.com/maguroid/skills/feedback-assetization/scripts/dreaming_nightly.py" --dry-run --hub "Workspace-Me"
```

手動で採掘窓を指定する場合:

```sh
uv run --no-project "$HOME/ghq/github.com/maguroid/skills/feedback-assetization/scripts/dreaming_nightly.py" --dry-run --window-hours 24
```

launchd 側の登録状態とログは次で見る。

```sh
launchctl print "gui/$(id -u)/com.maguroid.dreaming"
tail -f "$HOME/Library/Logs/dreaming.log"
```

## 撤去

ジョブを止め、plist を外す。

```sh
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.maguroid.dreaming.plist"
rm "$HOME/Library/LaunchAgents/com.maguroid.dreaming.plist"
```

作業中の一時 worktree が残っている場合は、対象ハブのリポジトリで `git worktree list` を
確認してから削除する。通常はスクリプト終了時に
`$HOME/.cache/dreaming/worktrees/<ハブ名>` が自動で掃除される。
