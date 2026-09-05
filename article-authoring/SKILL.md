---
name: article-authoring
description: "Zenn向け技術記事の企画・調査・執筆・編集・公開準備。個人・Publication共通。単なるWeb閲覧・要約・クリップは対象外。"
---

# Article Authoring

## 固定事項

- 公開先は当面Zennだけとする。
- 掲載主体を問わず、記事の正本は常に`$HOME/ghq/github.com/maguroid/posts`とする。
- 本文は`articles/<slug>.md`、画像は`images/<slug>/`、記事設計と編集判断は`editorial/<slug>.md`へ置く。
- 掲載主体側のリポジトリやwikiは、ブランド、機密、事実関係の参照元として使う。記事本文を複製しない。
- `published: false`を下書きの既定とする。`published: true`への変更は外部公開として扱う。

## 手順

1. 掲載主体とZenn上の個人アカウント／Publicationを既存記録から特定する。複数候補が残る場合だけ一問確認する。
2. `posts/AGENTS.md` と対象記事の編集方針を読む。企画・構成・文体の判断には
   `posts/editorial/principles.md`、配置やプレビュー手順が不明な場合には各 `README.md` を参照する。
   誤字修正などで無関係な資料を一式読み直さない。
3. 対象記事の`editorial/<slug>.md`やIssueがあれば読み、続きから作業する。
4. 必要な場合だけ、掲載主体や検証対象のリポジトリからブランド、機密、実装、一次情報を確認する。
5. ユーザーのフィードバックや再検証で判断が変わったら、記事別メモへ`before → after + 理由`を記録する。
6. 公開を明示されていなければ下書きまでに留める。公開前は`posts`のプレビューと検証手順を実行する。

Zenn以外への掲載を求められた場合は、このスキルで対応済みと仮定せず、単発対応かスキル拡張かを確認する。
