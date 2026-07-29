---
name: article-authoring
description: Zennへ公開する技術記事・テックブログ記事を企画、調査、検証、構成、執筆、編集、レビュー、公開準備するときに使う。個人名義と企業・組織のZenn Publication記事を問わず、すべての記事本文・画像・記事設計・編集判断の正本を`$HOME/ghq/github.com/maguroid/posts`で管理する。単なるWeb記事の閲覧・要約・クリップには使わない。
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
2. `posts/AGENTS.md`、`posts/README.md`、`posts/editorial/principles.md`、`posts/editorial/README.md`の順に読む。
3. 対象記事の`editorial/<slug>.md`やIssueがあれば読み、続きから作業する。
4. 必要な場合だけ、掲載主体や検証対象のリポジトリからブランド、機密、実装、一次情報を確認する。
5. ユーザーのフィードバックや再検証で判断が変わったら、記事別メモへ`before → after + 理由`を記録する。
6. 公開を明示されていなければ下書きまでに留める。公開前は`posts`のプレビューと検証手順を実行する。

Zenn以外への掲載を求められた場合は、このスキルで対応済みと仮定せず、単発対応かスキル拡張かを確認する。
