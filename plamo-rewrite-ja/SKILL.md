---
name: plamo-rewrite-ja
description: Rewrite text or text/markdown files into polished, natural Japanese using PLaMo 3.0 Prime via the llmx CLI. Use when the user wants to clean up, proofread, or 清書/推敲 a Japanese document while preserving its structure and information — e.g. "この資料を自然な日本語にして", "PLaMoで清書して", "メモを読みやすい日本語資料に", "rewrite this into natural Japanese with PLaMo". The result is always saved to a file. Default mode polishes (構成維持); it does not summarize or translate.
---

# PLaMo 3.0 Prime で自然な日本語へ清書する

`llmx`（OpenAI 互換 chat/completions を呼ぶゼロ依存 CLI）経由で **PLaMo 3.0 Prime**
にテキストや `.txt`/`.md` 資料を渡し、**意味・情報・構成を保ったまま自然で読みやすい
日本語へ清書・推敲** して、結果を**ファイルに保存**するスキル。

要約・翻訳・情報の追加削除はしない。あくまで「清書」。

## 前提（足りなければ先に解消する）

1. **`llmx` が PATH 上にある。** 無ければ:
   `go install github.com/maguroid/llmx@latest`（`$(go env GOPATH)/bin` を PATH に）。
2. **`~/.llmx/credentials` に `[plamo]` プロファイルがある。** 形は次のとおり
   （生鍵はファイルに書かず環境変数 `${PLAMO_API_KEY}` 展開を使う）:

   ```ini
   [plamo]
   base_url = https://api.platform.preferredai.jp/v1
   api_key  = ${PLAMO_API_KEY}
   model    = plamo-3.0-prime
   ```

   ディレクトリは `0700`、ファイルは `0600`。`PLAMO_API_KEY` をシェル環境に設定しておく。
   利用可能モデル: `plamo-3.0-prime`（262K ctx / 最大出力 20K）, `plamo-3.0-prime-beta`,
   `plamo-2.2-prime`。

確認だけしたいときは課金前に `llmx -p plamo --verbose ...` で stderr の解決結果を見る
（API キーはマスクされる）。

## 使い方（基本）

ファイルを清書して隣に保存する。ヘルパーがプロファイル確認・上書き防止・出力名の決定を行う。

```sh
"$HOME/.claude/skills/plamo-rewrite-ja/scripts/rewrite.sh" <input.md> [output.md]
```

- 出力先を省略すると `report.md → report.ja.md` のように `<stem>.ja.<ext>` を**入力の隣**に作る。
- 既存ファイルは**上書きしない**（明示パスを渡して回避）。
- 成果物パスは stderr に `wrote: <path>` と出る。stdout は汚さない。
- 環境変数で上書き可: `LLMX_PROFILE`（既定 `plamo`）, `LLMX_MODEL`（既定 `plamo-3.0-prime`）,
  `LLMX_REASONING`（既定 `medium`。`none` で推論オフ）。`max_tokens` は**意図的に指定しない**
  （理由は下記の落とし穴を参照）。

### インラインのテキスト／メモを清書する

ユーザーがファイルではなく本文を直接渡した場合は、まずそれを UTF-8 のテキストファイルに
保存してから `rewrite.sh` に渡す（出力は必ずファイル保存という方針のため）。保存先が不明なら
カレントに `*.ja.md` で作るか、ユーザーに置き場所を確認する。

```sh
printf '%s' "$user_text" > draft.md
"$HOME/.claude/skills/plamo-rewrite-ja/scripts/rewrite.sh" draft.md
```

## 手元で何が起きているか（透明性のため）

ヘルパーは実質これを実行している。動作を調整したいときはこの形で直接呼んでよい。

```sh
llmx -p plamo -m plamo-3.0-prime --stream --reasoning-effort medium \
  --system "<清書用システムプロンプト>" \
  "この方針に従って次の原稿を清書し、本文のみを出力してください。" \
  < input.md > output.md
```

- 原稿は **stdin**（`< input.md`）で渡す。位置引数は短い指示文。挙動はシステムプロンプトが
  完全に規定するので、結合順序に依存しない。
- **`--stream` は必須。** PLaMo は非ストリーミングだと全文生成が終わるまで応答ヘッダを返さず、
  長文では `llmx` が「timeout awaiting response headers」（exit 4）で打ち切られる。`--stream` なら
  ヘッダ・先頭トークンが即座に返るのでタイムアウトしない。ストリーミングでも **stdout は応答本文のみ**
  なので、そのままファイルへリダイレクトできる。
- ファイルをパイプ／リダイレクトしているので `< /dev/null` は付けない（付けると入力が消える）。

システムプロンプトの全文は `scripts/rewrite.sh` を参照（保持／改善／禁止事項を明記している）。

## llmx 由来の落とし穴

- **フラグはプロンプトより前。** `flag` パーサは最初の位置引数で止まる。
- **終了コードで分岐する。** `0` 成功 / `1` API・プロトコル / `2` usage / `3` 設定 /
  `4` ネットワーク・タイムアウト / `130` 中断。`rewrite.sh` は設定不足を `3`、ローカル不備を `2` で返す。
- **非ストリーミングはヘッダ待ちでタイムアウトする。** PLaMo は全文生成後にまとめて応答を返すため、
  長文では応答ヘッダが届く前に `llmx` のHTTPクライアントが諦める（exit 4「timeout awaiting response
  headers」）。ネットワーク遮断と紛らわしいが原因は別。**`--stream` を付ければ回避できる**（`rewrite.sh`
  は既定で付与済み）。
- **`reasoning_effort` は出力予算（max_tokens）を食う。** `--reasoning-effort`（`rewrite.sh` は既定
  `medium`）で推論を効かせると、推論トークンも `max_tokens` の枠に算入される。固定上限を切ると推論が
  枠を食い潰し、本文が空のまま `finish_reason=length` で打ち切られることがある（2行の入力でも推論だけで
  120トークン超を消費した実測あり）。**対策は `max_tokens` を指定しないこと**。サーバ既定に任せれば推論＋
  本文が最後まで完了する（`rewrite.sh` は `--max-tokens` を付けない）。推論を切りたいときは
  `LLMX_REASONING=none`。

## 長い原稿・途中で切れたとき

PLaMo 3.0 Prime の最大出力は **20,000 トークン**。`max_tokens` を指定しなければサーバ既定で
ここまで使えるが、それを超える長文は末尾が切れることがある。疑わしいときは `--json` で
`finish_reason` を確認する（`length` なら切れている）:

```sh
out="$(llmx -p plamo -m plamo-3.0-prime --reasoning-effort medium --json \
  --system "<清書用システムプロンプト>" \
  "この方針に従って次の原稿を清書し、本文のみを出力してください。" < input.md)"
printf '%s' "$out" | jq -r '.finish_reason'   # stop なら完了 / length なら途中
printf '%s' "$out" | jq -r '.content' > output.md
```

> 注意: `--json` は `--no-stream` を含意するため、長文では上記「ヘッダ待ちタイムアウト」に当たりやすい。
> `finish_reason` 確認は短い断片で使うか、本処理は `--stream`、確認は別途短文で、と使い分ける。

切れている場合は原稿を見出し単位などで分割し、各断片を清書して結合する（末尾が欠けたら、欠落
セクションだけを同じ手順で清書して追記すればよい。チェックリスト等の清書余地が乏しい箇所は原文を
忠実に復元する方が安全）。

## 応用: 清書ではなく「資料化」したいとき

既定は構成維持の清書。断片的なメモを見出し・段落のある資料へ**再構成**してほしいと
明示された場合は、`rewrite.sh` のシステムプロンプトを差し替える（構成の再編成を許可し、
情報は保持しつつ整理する指示にする）。情報の追加・要約はしない方針は維持する。

## 出力後

- 保存パスをユーザーに伝え、必要なら本文も提示する。
- **元ファイルは上書きしない。** 清書結果は別ファイル。
