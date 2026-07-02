---
name: hashigodaka-wiki
description: Add or update knowledge in the Hashigodaka team wiki ($HOME/Projects/Hashigodaka/wiki), an OKF-compliant Markdown knowledge base. Use when the user asks to record, add, or update team-shared knowledge in the wiki — e.g. "wikiに追記して", "wikiに記載したい", "この手順をwikiにまとめて", "ナレッジ化して", or any mention of the Hashigodaka wiki / ~/Projects/Hashigodaka/wiki. Covers topic-directory selection, hub-vs-fulltext judgment, OKF frontmatter, index/log updates, and the direct commit-and-push workflow this wiki requires.
---

# Hashigodaka wiki への寄稿

チーム共有ナレッジ基盤 `$HOME/Projects/Hashigodaka/wiki`（GitHub: `pao-tech-labs/wiki`, private）に
OKF準拠のMarkdownでナレッジを追記・更新するワークフロー。

## 最初に必ずやること

運用ルールの正本は **wiki側の `AGENTS.md`**。このスキルは要約にすぎない。作業前に必ず読む:

1. `$HOME/Projects/Hashigodaka/wiki/AGENTS.md` — 運用ルール・ディレクトリ構成・寄稿手順の正本
2. `conventions/okf-authoring.md` — frontmatter・type語彙・命名・リンク規約
3. `conventions/hub-vs-fulltext.md` — ハブ型/全文型の判定基準

このスキルと正本が食い違ったら正本に従い、必要ならこのスキルを更新する。

## 寄稿手順（凝縮版）

1. **置き場の判定**: 個人的なコンテキストはこのwikiに置かない（Workspace-HSG行き）。
   チームで再利用される確定ナレッジのみ置く。
2. **ハブ型/全文型の判定**: 正本が外部（Notion/Drive等）にあるなら要約＋`resource` のハブ型、
   wikiが正本になるなら全文型。
3. **主題ディレクトリの選定**: `projects/` `clients/` `rules/` `specs/` `meetings/` `glossary/`。
   種類はディレクトリでなく frontmatter の `type` で表す。新しい主題が必要なら
   AGENTS.md の構成図も更新する。
4. **執筆**: 規約に従って作成・更新。
   - frontmatter 必須は `type` のみ（閉じた語彙: `プロジェクト`/`取引先`/`ルール`/`仕様`/
     `議事録`/`用語`/`意思決定`。増やすなら先に okf-authoring.md のリストへ追記）。
     `title`/`description`/`tags`/`timestamp`(ISO 8601) は推奨、`resource` はハブ型で必須。
   - ファイル名は安定した kebab-case スラッグ（パス＝概念ID。日付・ステータスを埋めない。
     例外: 議事録は `YYYY-MM-DD-<topic>.md`）。
   - リンクは相対パス。リンク切れは未執筆知識の予約として許容。
5. **相互リンク**: 関連ファイルへエッジを張る（関係の意味は本文で説明）。
6. **目次・履歴の更新**: 主題ディレクトリの `index.md` に目次エントリ追加。
   ルート `log.md` に履歴を追記（新しい順の先頭。日付グループあり）。
   ルート `index.md` に載せる粒度ならそちらも更新。
7. **コミット＆プッシュ**: ユーザーへ事前確認せず `main` へ直接コミット＆プッシュする
   （wikiの明文ルール）。変更内容を表す明確なメッセージで、無関係な変更を混ぜない。

## ハマりどころ

- **自動同期フックは他リポジトリのセッションでは効かない**: wikiの Stop フック
  （自動コミット&push）は、セッションの作業ディレクトリがwiki自身のときだけ動く。
  別リポジトリでの作業中にwikiへ寄稿した場合は、**必ず手動で commit & push まで行う**
  （忘れると他端末・他メンバーから見えない）。
- push 前に `git -C $HOME/Projects/Hashigodaka/wiki pull --ff-only` で最新化しておくと
  複数端末運用での競合を避けられる。
- ドキュメントは日本語で書く（明示指示がない限り）。
- `index.md` は frontmatter 無しの目次（ルート `index.md` のみ `okf_version` を宣言）。
  `log.md` は新しい順。
