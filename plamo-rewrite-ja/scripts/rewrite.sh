#!/usr/bin/env bash
# Rewrite a Japanese (or Japanese-mixed) text/markdown file into polished,
# natural Japanese using PLaMo 3.0 Prime via the `llmx` CLI.
#
# Behavior: preserves the original structure, information, and Markdown markup;
# fixes typos, particles, unnatural phrasing, and redundancy. It does NOT
# summarize, translate, add, or remove information.
#
# Usage:
#   rewrite.sh <input-file> [output-file]
#
# - <input-file>  : a .txt / .md (or any UTF-8 text) file to rewrite.
# - [output-file] : where to write the result. Defaults to "<stem>.ja.<ext>"
#                   next to the input (e.g. report.md -> report.ja.md).
#                   The script refuses to overwrite an existing file.
#
# Env overrides:
#   LLMX_PROFILE    (default: plamo)   llmx credentials profile to use.
#   LLMX_MODEL      (default: plamo-3.0-prime)
#   LLMX_REASONING  (default: medium)  reasoning_effort for the polish pass.
#                                      Set to "none" to disable.
#
# max_tokens is intentionally NOT set: the API's cap counts reasoning tokens
# too, so a fixed cap would let reasoning starve the visible output (and
# truncate). Leaving it unset lets reasoning + the full rewrite complete.
#
# Exit codes follow llmx where possible: 2 = usage/local error, others bubble
# up from llmx (1 API, 3 config, 4 network, 130 interrupted).
set -euo pipefail

PROFILE="${LLMX_PROFILE:-plamo}"
MODEL="${LLMX_MODEL:-plamo-3.0-prime}"
REASONING="${LLMX_REASONING:-medium}"

in="${1:-}"
if [ -z "$in" ]; then
  echo "usage: rewrite.sh <input-file> [output-file]" >&2
  exit 2
fi
if [ ! -f "$in" ]; then
  echo "input file not found: $in" >&2
  exit 2
fi

out="${2:-}"
if [ -z "$out" ]; then
  base="$(basename -- "$in")"
  dir="$(dirname -- "$in")"
  case "$base" in
    *.*) out="$dir/${base%.*}.ja.${base##*.}" ;;
    *)   out="$dir/${base}.ja" ;;
  esac
fi
if [ -e "$out" ]; then
  echo "refusing to overwrite existing file: $out" >&2
  echo "pass an explicit second argument to choose a different path." >&2
  exit 2
fi

if ! command -v llmx >/dev/null 2>&1; then
  echo "llmx not found on PATH. Install with:" >&2
  echo "  go install github.com/maguroid/llmx@latest" >&2
  echo "and ensure \$(go env GOPATH)/bin is on PATH." >&2
  exit 3
fi
if [ ! -f "$HOME/.llmx/credentials" ]; then
  echo "missing ~/.llmx/credentials. Add a [$PROFILE] profile (see SKILL.md)." >&2
  exit 3
fi

read -r -d '' SYS <<'EOF' || true
あなたは経験豊富な日本語の編集者・校正者です。受け取った原稿を、自然で読みやすい日本語の文書に清書・推敲してください。

【保持すること】
- 原稿の構成（見出し・箇条書き・段落の順序と階層）
- すべての事実・情報・数値・固有名詞・引用
- Markdown 記法（見出し記号、リスト、コードブロック、リンク、表など）
- 原文の文体（敬体「です・ます」／常体「だ・である」は原文に合わせる。混在していれば全体を自然な方へ統一する）

【改善すること】
- 誤字・脱字・変換ミス
- 助詞や送り仮名の誤り、ねじれた文・主述の不一致
- 不自然な言い回し、冗長・重複した表現、回りくどい説明
- 一文が長すぎる箇所の適切な分割、読点の整理

【してはいけないこと】
- 情報の追加・削除・要約。書かれていない内容を補わない
- 過度な意訳や脚色、トーンの大幅な変更
- 英語など他言語への翻訳（原文が日本語以外を含む場合はその部分の意味を変えない）
- 「以下が清書版です」などの前置き・後書き・解説の出力

出力は清書後の本文のみとし、原稿全体を返してください。
EOF

# The document is piped on stdin; the positional arg is a short directive.
# The system prompt fully specifies behavior, so the prompt/stdin order is
# irrelevant. Plain (non --json) output means stdout is the response body only.
#
# --stream is required: PLaMo computes the whole completion before sending a
# non-streaming response, so for long inputs the response headers do not arrive
# until generation finishes and llmx's HTTP client gives up ("timeout awaiting
# response headers"). Streaming makes the headers/first tokens arrive
# immediately, avoiding the timeout. stdout still receives only the response
# body, so the redirect to "$out" stays clean.
#
# --reasoning-effort defaults to "medium" so the polish pass gets a deliberate
# review rather than PLaMo's "none" default; override with LLMX_REASONING.
llmx -p "$PROFILE" -m "$MODEL" --stream \
  --reasoning-effort "$REASONING" --system "$SYS" \
  "この方針に従って次の原稿を清書し、本文のみを出力してください。" \
  < "$in" > "$out"

echo "wrote: $out" >&2
