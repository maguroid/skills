# ベンダリング元

このスキルは npm パッケージ `@playwright/cli`（v0.1.15）が生成する公式スキルの複製です。
手書きで編集しないこと。パッケージ更新後は次で再生成して差し替える:

```sh
cd "$(mktemp -d)" && playwright-cli install --skills
rsync -a --delete --exclude VENDORED.md .claude/skills/playwright-cli/ "$HOME/ghq/github.com/maguroid/skills/playwright-cli/"
```

導入経緯: 2026-07-05、フロントエンド検証エージェントの状態確認ツールを
Playwright MCP から CLI 系へ切り替えた際に導入（詳細は Workspace-Me
notes/agent-frontend-verification-2026.md 第7節）。
