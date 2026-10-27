---
name: tachyon-browser
description: Use the Tachyon k3s Cloudflare Mesh remote Chromium CDP gateway with agent-browser, Playwright, Codex, or Claude Code. Trigger when a task needs a browser reachable from Sakura VPS or another Mesh client, remote CDP automation, temporary browser sessions, named browser sessions, or AgentCore Browser-like session-per-Pod browser control through browser-cdp.intra.quantum-box.com.
---

# Tachyon Browser

Use this skill to control the k3s-hosted Chromium CDP gateway at:

```text
browser-cdp.intra.quantum-box.com:9222
```

The gateway creates one Chromium Pod per session and exposes it as a CDP WebSocket URL. It is intended for Cloudflare Mesh / WARP clients, such as Sakura VPS Claude Code, local Codex, and local automation.

## Authentication

Every route except `/healthz` and `/readyz` requires a bearer token.

- API token: lists, creates, and deletes sessions. Stored in 1Password; export it as `TACHYON_BROWSER_API_TOKEN` before using this skill. Do not print it or paste it into logs, URLs, or commit messages.
- Session token: returned by `POST /sessions` and embedded in `cdp_ws_url` as `/sessions/<session_id>/<session_token>`. It reaches only that session's browser. Treat `cdp_ws_url` as a secret.

```bash
export TACHYON_BROWSER_API_TOKEN="$(op read 'op://<vault>/<item>/api-token')"
GATEWAY="http://browser-cdp.intra.quantum-box.com:9222"
# Used as `curl -H @<(auth)` so the token stays out of the curl command line.
auth() { printf 'Authorization: Bearer %s\n' "$TACHYON_BROWSER_API_TOKEN"; }
```

The examples below assume `GATEWAY` and `auth` are defined.

## Rules

- Always get the CDP URL from the `cdp_ws_url` field of `POST /sessions`. Do not build `ws://.../sessions/<id>` yourself; without the session token the gateway returns 401.
- Do not pass the `cdp_http_url` (`http://.../sessions/...`) to `agent-browser`; its HTTP CDP handling drops the path and falls back to the shared root browser.
- Use the same value for the remote session id and `agent-browser --session` when possible. This avoids local daemon confusion.
- Session ids must match `[A-Za-z0-9._-]{1,96}`.
- `POST /sessions` with the same `session_id` reuses the running Pod and returns the same session token.
- Named session state, including cookies, localStorage, and cache, persists while the session Pod is alive.
- Session state is lost when the Pod is deleted by idle timeout, TTL, or explicit DELETE.
- Idle timeout is 30 minutes. Absolute TTL is 6 hours.

## Named Session

Use a named session when the user wants to reconnect to the same browser during a task.

```bash
SESSION_ID="sakura-job-001"

CDP_WS="$(curl -sS --fail-with-body -X POST -H @<(auth) \
  -H 'content-type: application/json' \
  -d "{\"session_id\":\"${SESSION_ID}\"}" \
  "${GATEWAY}/sessions" | jq -r .cdp_ws_url)"

agent-browser \
  --cdp "$CDP_WS" \
  --session "${SESSION_ID}" \
  open https://example.com
```

Continue using the same `CDP_WS` and `SESSION_ID` for subsequent commands:

```bash
agent-browser \
  --cdp "$CDP_WS" \
  --session "${SESSION_ID}" \
  snapshot -i
```

Delete the remote browser when done:

```bash
curl -sS -X DELETE -H @<(auth) "${GATEWAY}/sessions/${SESSION_ID}" | jq .
```

## Temporary Session

Use a temporary session when the user does not care about the session id.

```bash
SESSION_JSON="$(curl -sS --fail-with-body -X POST -H @<(auth) "${GATEWAY}/sessions")"
SESSION_ID="$(printf '%s' "$SESSION_JSON" | jq -r .session_id)"
CDP_WS="$(printf '%s' "$SESSION_JSON" | jq -r .cdp_ws_url)"

agent-browser \
  --cdp "$CDP_WS" \
  --session "$SESSION_ID" \
  open https://example.com

curl -sS -X DELETE -H @<(auth) "${GATEWAY}/sessions/${SESSION_ID}" | jq .
```

## Wrapper Script

Prefer the bundled helper when doing one-off checks. It reads the API token from `TACHYON_BROWSER_API_TOKEN` and never prints it. In Claude Code, the plugin's `bin/` directory is added to PATH, so use `remote-browser` directly:

```bash
remote-browser \
  --temporary \
  --cleanup \
  -- open https://example.com
```

When using this skill folder directly outside a Claude plugin install, resolve the script path relative to this skill directory:

```bash
scripts/remote-browser.sh \
  --temporary \
  --cleanup \
  -- open https://example.com
```

Use a named browser:

```bash
scripts/remote-browser.sh \
  --session-id sakura-job-001 \
  -- open https://example.com
```

Create a temporary session and keep it:

```bash
scripts/remote-browser.sh \
  --temporary \
  --keep \
  -- open https://example.com
```

Print only the `cdp_ws_url` (for Playwright or another CDP client):

```bash
CDP_WS="$(scripts/remote-browser.sh --session-id sakura-job-001)"
```

The script prints the remote `session_id` and the `cdp_ws_url` with the session token masked to stderr before running `agent-browser`. `--list` and `--delete SESSION_ID` use the API token. `TACHYON_BROWSER_GATEWAY` or `--gateway URL` overrides the gateway.

## Inspect Sessions

```bash
curl -sS "${GATEWAY}/readyz"
curl -sS -H @<(auth) "${GATEWAY}/sessions" | jq .
curl -sS -H @<(auth) "${GATEWAY}/sessions/<session_id>/json/version" | jq .
```

The session list includes `last_access_at`, `idle_seconds`, `idle_timeout_seconds`, and `ttl_seconds`.

## Playwright

For Playwright or direct CDP clients, connect to the WebSocket URL:

```js
import { chromium } from 'playwright';

// CDP_WS is the cdp_ws_url from POST /sessions, for example
// `scripts/remote-browser.sh --session-id sakura-job-001`.
const browser = await chromium.connectOverCDP(process.env.CDP_WS);
```

## Troubleshooting

- If a request returns 401, check that `TACHYON_BROWSER_API_TOKEN` is set, and that the CDP URL is the `cdp_ws_url` from `POST /sessions` (it must include the session token segment).
- If commands affect the wrong browser, check whether the command used the `http://` `cdp_http_url` instead of the `ws://` `cdp_ws_url`.
- If a session has stale local `agent-browser` state, close it with `agent-browser --session <name> close` and reconnect with the WebSocket CDP URL.
- If `remote-browser` is not found in Claude Code, verify the plugin is enabled and run `/reload-plugins`.
- If the gateway is unreachable, verify the machine is on Cloudflare Mesh / WARP and check `/readyz`.
- If Japanese text appears as boxes, verify the running session Pod uses the Playwright image with `fonts-noto-cjk`; the current gateway template installs it at startup.
- If durable browser profile state is required after Pod deletion, the current gateway does not provide that yet. It needs per-session PVC-backed `--user-data-dir`.
