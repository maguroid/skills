## ヘッドレス / 定期実行

- 単発の非対話実行: `pi --mode json "prompt"` — JSON Lines でイベントが流れる。
  例: `pi --mode json "List files" 2>/dev/null | jq -c 'select(.type == "message_end")'`
- プロセス統合: `pi --mode rpc` — stdin/stdout の JSONL 双方向プロトコル。
  行区切りは `\n` のみ（`\r\n` は末尾 `\r` 除去で許容。Unicode 改行類似文字を改行と
  みなす汎用ラインリーダーは使わないこと、と公式明記）
- Docker 化の公式例:

```dockerfile
FROM node:24-bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent
WORKDIR /workspace
ENTRYPOINT ["pi"]
```
