---
name: xurl-article-reader
description: Fetch full X Article bodies through xurl when a user asks Codex to search X, read posts, summarize posts, explain posts, analyze X threads, or answer questions about X content that may include x.com/i/article links or Tweet/Post article attachments. Use alongside the xurl skill whenever Article title or preview text is insufficient and the full article.plain_text should be retrieved from the parent post with tweet.fields=article.
---

# Xurl Article Reader

## Overview

Use this skill to reliably retrieve X Article body text while handling X content through `xurl`. The key detail is that the Article body is returned from the parent post lookup when `tweet.fields=article` is requested; direct `GET /2/articles/{id}` is not the reliable path.

## Workflow

1. Start with the X post URL or post ID the user provided, or the post IDs found during X search.
2. Run normal post retrieval first if needed:

```sh
xurl read "https://x.com/user/status/POST_ID"
```

3. If the response includes an `article` object, an `x.com/i/article/...` URL, or only an Article title/preview, fetch the parent post again with `tweet.fields=article`:

```sh
xurl "/2/tweets/POST_ID?tweet.fields=article,created_at,public_metrics,conversation_id,entities,attachments&expansions=author_id&user.fields=username,name,verified"
```

4. Use `data.article.plain_text` as the Article body. Preserve `data.article.title`, `data.article.preview_text`, media IDs, mentions, embedded tweet IDs, author, created time, and public metrics when they matter to the user's summary or explanation.
5. If multiple search results or posts may contain Articles, repeat the explicit lookup for each candidate before summarizing. Do not summarize only the title, t.co URL, or preview text when `article.plain_text` is available.

## ID Handling

Use the status/post ID for the `/2/tweets/{id}` lookup. If the post contains:

```json
"expanded_url": "http://x.com/i/article/ARTICLE_ID"
```

do not replace the post ID with `ARTICLE_ID` for the tweet lookup. The Article ID identifies the Article URL, but the full body is exposed through the parent post's `article` field.

## Expected Shape

Successful responses can include:

```json
{
  "data": {
    "text": "https://t.co/...",
    "article": {
      "title": "...",
      "preview_text": "...",
      "plain_text": "...full body...",
      "cover_media": "3_...",
      "media_entities": ["3_..."]
    }
  }
}
```

`xurl read POST_URL` may only show `article.title` depending on its default fields. Treat that as a signal to rerun the raw `/2/tweets/{id}` lookup with `tweet.fields=article`.

## Failure Handling

- If `xurl` fails with DNS, connection, API, or auth-looking errors inside the sandbox, retry the same command with `sandbox_permissions: "require_escalated"` before concluding that X or credentials are broken.
- If `/2/articles/ARTICLE_ID` returns `{}` or `request failed`, do not treat that as proof the Article is unreadable. Use the parent post lookup with `tweet.fields=article`.
- If the explicit lookup does not include `data.article.plain_text`, report that the Article body was not available from the API response and distinguish that from normal post text retrieval.
- Never read or print `~/.xurl`, never ask the user to paste credentials, and never use xurl verbose mode or inline secret flags.

## Example

For:

```text
https://x.com/noobbotter3/status/2061703818975564149
```

use:

```sh
xurl "/2/tweets/2061703818975564149?tweet.fields=article,created_at,public_metrics,conversation_id,entities,attachments&expansions=author_id&user.fields=username,name,verified"
```
