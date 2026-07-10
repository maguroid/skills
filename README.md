# skills

エージェント中立なグローバルスキルの正本リポジトリ。各ディレクトリが1スキルで、
エージェント向けの定義は各 `SKILL.md`、人間向けの説明は各スキル内の `README.md`
（あるもののみ）を参照。

- エージェント中立スキルは `$HOME/.agents/skills` と `$HOME/.claude/skills`、
  Claude Code 専用スキルは `$HOME/.claude/skills`、Codex 専用スキルは
  `$HOME/.codex/skills` へのシンボリックリンクで発見させる。新しい端末では
  `./bootstrap.sh` を実行（冪等）。
- スキルの追加・更新・移行の手順は `global-skill-workflow` スキルが定義元。

## 記憶システムと資産化の型

`feedback-assetization` は「暗黙の受け入れ基準の資産化」の型と、その基盤である
ハブ型記憶システムを一体で提供する。導入方法は同スキルの README.md を参照
（インストール後、エージェントに「この環境に記憶システムをセットアップして」と
伝えるのが最初の一声）。
