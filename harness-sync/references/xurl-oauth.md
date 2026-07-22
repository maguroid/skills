# xurl per-device OAuth setup

Treat a working machine and the X Developer Portal as the configuration reference, but
never copy the working machine's whole `~/.xurl`. Before creating or changing anything,
have the user run these non-secret diagnostics on the working machine when available:

```sh
xurl --version
xurl auth apps list
xurl auth apps redirect-uri get default
xurl auth status
```

Match the new machine's app name and callback URI to that output and to the Developer
Portal **exactly**. Do not normalize `localhost` to `127.0.0.1` (or the reverse): X
requires an exact callback match, and xurl's historical default is
`http://localhost:8080/callback`. Register OAuth **2.0 Client ID / Client Secret**, not
the OAuth1 API Key / API Key Secret. Never ask the user to paste either credential into
chat. For a zsh session, offer this history-safe setup:

```zsh
read -r "client_id?OAuth2 Client ID: "
read -rs "client_secret?OAuth2 Client Secret: "; printf '\n'
xurl auth apps add default --client-id "$client_id" --client-secret "$client_secret" \
  --redirect-uri 'http://localhost:8080/callback'
unset client_id client_secret
xurl auth oauth2 USERNAME --app default
```

If `app "default" already exists`, repeat the credential prompts and use this instead of
`apps add`:

```zsh
xurl auth apps update default --client-id "$client_id" \
  --client-secret "$client_secret" \
  --redirect-uri 'http://localhost:8080/callback'
unset client_id client_secret
```

To change only the callback, use:

```sh
xurl auth apps redirect-uri set default 'http://localhost:8080/callback'
```

For X's generic “You weren't able to give access to the App” page, inspect in this order:
effective callback (`redirect-uri get`), exact Developer Portal callback, selected app
and non-empty credentials (`apps list` / `status`), OAuth2-vs-OAuth1 credential type,
then app permissions/package state. Client Secret is used at token exchange, so a failure
on the authorization page itself points first to Client ID, callback, scopes, or X-side
app state. After success, verify `xurl auth status` shows the username under OAuth2.
