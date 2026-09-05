---
name: xurl-article-reader
description: "Read X posts, threads, and full X Articles with xurl, including when a post lookup returns only an Article preview."
---

# Xurl Article Reader

Read X posts and Article bodies using the parent post ID. In this environment select the existing app explicitly:

```sh
xurl --app default read "https://x.com/user/status/POST_ID"
```

If only an Article title/preview or `x.com/i/article/...` is returned, request its full body:

```sh
xurl --app default "/2/tweets/POST_ID?tweet.fields=article,created_at,entities&expansions=author_id&user.fields=username,name"
```

Use `data.article.plain_text` as the body. Keep the author, title, date, and source link when relevant.
The lookup uses the status/post ID, not the Article ID; do not substitute `/2/articles/{id}`.
Fetch additional media or metrics only if the task needs them.

Never read/print `~/.xurl`, use verbose mode, or ask for pasted credentials.
After a sandbox network/auth error, retry the exact command with escalation before diagnosing auth.
If retrieval remains unavailable, use an available authorized browser to read the source, or ask for its text.
Do not change accounts or authentication merely to read one post. Distinguish full body, preview, and unavailable content.
After retrieval, continue the original task (such as refactoring or clipping); reading is not its completion.
