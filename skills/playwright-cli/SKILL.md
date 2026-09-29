---
name: playwright-cli
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Use Playwright CLI for lightweight browser verification only when browser-test/agent-browser
  is unavailable or the user explicitly requests CLI; it can also manage saved auth state.
---

# Playwright CLI Browser Verification

Lightweight browser automation via `playwright-cli` Bash commands.
MCP が使えない場合や、コンテキスト消費を抑えたい場合に使用する。

## Binary Path

```
/home/ubuntu/.npm-global/bin/playwright-cli
```

Alias for convenience:
```bash
CLI=/home/ubuntu/.npm-global/bin/playwright-cli
```

## Port Configuration

**必ず `docker compose ps` で実際のポートを確認すること。**

| Service | Env Var | worktree1 Default |
|---------|---------|-------------------|
| Tachyon | `TACHYON_HOST_PORT` | 16000 |
| Tachyon API | `TACHYON_API_HOST_PORT` | 50054 |

```bash
docker compose ps
grep "_HOST_PORT" .env
```

## Workflow

### Step 1: Open browser & navigate

```bash
$CLI --session=verify open http://localhost:${TACHYON_HOST_PORT}/sign_in
```

### Step 2: Snapshot — get element refs

```bash
$CLI --session=verify snapshot
```

Output is saved to `.playwright-cli/page-*.yml` (YAML accessibility tree with `[ref=eNN]`).
Read the yml file to get refs for interaction.

### Step 3: Interact using refs

```bash
$CLI --session=verify fill <ref> <text>
$CLI --session=verify click <ref>
$CLI --session=verify select <ref> <value>
$CLI --session=verify hover <ref>
$CLI --session=verify press <key>
$CLI --session=verify type <text>
```

### Step 4: Screenshot

```bash
$CLI --session=verify screenshot
$CLI --session=verify screenshot <ref>   # element screenshot
```

Screenshots saved to `.playwright-cli/page-*.png`.

### Step 5: Cleanup

```bash
$CLI --session=verify close
# or close all sessions:
$CLI close-all
```

## Login Flow (Tachyon)

```bash
CLI=/home/ubuntu/.npm-global/bin/playwright-cli
PORT=$(grep TACHYON_HOST_PORT .env | cut -d= -f2)

# 1. CSRF token acquisition (required for NextAuth)
$CLI --session=verify open http://localhost:${PORT}/api/auth/csrf

# 2. Navigate to sign_in
$CLI --session=verify goto http://localhost:${PORT}/sign_in

# 3. Snapshot to get refs
$CLI --session=verify snapshot
# Read the .yml file, find Username (e.g. e19), Password (e.g. e21), Sign in button (e.g. e22)

# 4. Fill & submit
$CLI --session=verify fill e19 test
$CLI --session=verify fill e21 'hmw2atd@HCF3qwu*rcn'
$CLI --session=verify click e22

# 5. Save auth state for reuse
$CLI --session=verify state-save .playwright-cli/auth-state.json

# 6. Verify redirect
$CLI --session=verify screenshot
```

## Auth State Reuse

Save once, load in new sessions:

```bash
# Save after login
$CLI --session=verify state-save .playwright-cli/auth-state.json

# Load in new session (skip login)
$CLI --session=new open http://localhost:${PORT}
$CLI --session=new state-load .playwright-cli/auth-state.json
$CLI --session=new goto "http://localhost:${PORT}/v1beta/${TACHYON_TEST_TENANT_ID}/ai/agent/chat"
```

## Command Reference

### Core
| Command | Description |
|---------|-------------|
| `open [url]` | Open browser |
| `close` | Close browser |
| `goto <url>` | Navigate to URL |
| `click <ref>` | Click element |
| `fill <ref> <text>` | Fill text field |
| `type <text>` | Type text into focused element |
| `select <ref> <val>` | Select dropdown option |
| `hover <ref>` | Hover over element |
| `snapshot` | Capture accessibility tree (→ `.yml`) |
| `screenshot [ref]` | Capture screenshot (→ `.png`) |

### Navigation
| Command | Description |
|---------|-------------|
| `go-back` | Browser back |
| `go-forward` | Browser forward |
| `reload` | Reload page |

### Keyboard / Mouse
| Command | Description |
|---------|-------------|
| `press <key>` | Press key (e.g. `Enter`, `ArrowDown`) |
| `resize <w> <h>` | Resize viewport |

### Storage / Auth
| Command | Description |
|---------|-------------|
| `state-save [file]` | Save auth state |
| `state-load <file>` | Load auth state |
| `cookie-list` | List cookies |
| `cookie-clear` | Clear cookies |

### DevTools
| Command | Description |
|---------|-------------|
| `console` | Show console messages |
| `network` | Show network requests |
| `eval <func> [ref]` | Evaluate JavaScript |
| `tracing-start` | Start trace recording |
| `tracing-stop` | Stop trace recording |

### Sessions
| Command | Description |
|---------|-------------|
| `list` | List browser sessions |
| `close-all` | Close all sessions |
| `--session=<name>` | Use named session (option) |

## Output Files

All output goes to `.playwright-cli/`:
- `page-*.yml` — Accessibility tree snapshots
- `page-*.png` — Screenshots
- `console-*.log` — Console logs
- `auth-state.json` — Saved auth state

After verification, move screenshots to taskdoc:
```bash
mv .playwright-cli/*.png docs/src/tasks/in-progress/<task>/screenshots/
```

## Tips

- **CSRF token**: Always visit `/api/auth/csrf` before login (NextAuth requirement)
- **Refs change**: After navigation or DOM update, run `snapshot` again to get fresh refs
- **Session persistence**: Use `--session=<name>` to keep browser open across commands
- **Mobile test**: `resize 375 667` before screenshot for mobile verification
- **Context efficiency**: ~1.3% context increase vs MCP's ~8%

## vs MCP / vs @playwright/test

| Aspect | playwright-cli | Playwright MCP | @playwright/test |
|--------|---------------|----------------|------------------|
| Context cost | ~1.3% | ~8% | N/A (separate process) |
| Method | Bash commands | Tool calls | Test runner |
| Use case | Routine verification | Interactive debug | Regression tests |
| Command | `mise run e2e-smoke` | MCP tools | `$CLI --session=x ...` |
