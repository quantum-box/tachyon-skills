---
name: browser-test
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Verify browser UI behavior with agent-browser when the user asks for 動作確認/verification or a
  requested UI change needs user-flow evidence. Do not trigger for every UI edit or
  automatically after implementation.
---

# Browser Test

Verify UI behavior using `agent-browser`.

This skill is now a thin compatibility wrapper. For browser verification, use the `agent-browser` workflow and commands directly rather than Playwright MCP tools.

## App Configuration

### Tachyon (Main App)
```yaml
url: http://localhost:16000
tenant_path: /v1beta/<tenant-id>
full_url: http://localhost:16000/v1beta/<tenant-id>
credentials:
  id: test
  password: "${TACHYON_TEST_PASSWORD}"
  # Load the value from ignored local configuration; never store it in this file.
backend_api: http://localhost:50054
graphql: http://localhost:50054/v1/graphql
```

### Library
```yaml
url: http://localhost:5010
credentials:
  # GitHub OAuth login
```

### TACHYON Field UI
```yaml
url: http://localhost:3000
```

### TACHYON Field Admin UI
```yaml
url: http://localhost:3001
```

### AI Chat
```yaml
url: http://localhost:16000
api_base: http://localhost:16000
```

## Common Headers (API Testing)
```yaml
Authorization: Bearer dummy-token
x-operator-id: <tenant-id>
# x-user-id: optional (defaults to seed user)
```

## agent-browser Commands

### Navigation
- `agent-browser open <url>` - Go to URL
- `agent-browser get url` - Check current URL
- `agent-browser wait --load networkidle` - Wait for page settle

### Interaction
- `agent-browser click @e1` - Click element
- `agent-browser fill @e2 "text"` - Fill input
- `agent-browser select @e3 "option"` - Select dropdown option
- `agent-browser press Enter` - Keyboard input

### Inspection
- `agent-browser snapshot -i` - Interactive elements with refs
- `agent-browser screenshot` - Visual capture
- `agent-browser network requests` - View requests if needed

### Other
- `agent-browser wait --text "..."` - Wait for text
- `agent-browser wait 2000` - Wait fixed time
- `agent-browser get text @e1` - Inspect text

## Workflow

1. **Navigate**: `agent-browser open <url>`
2. **Snapshot**: `agent-browser snapshot -i` to get refs
3. **Interact**: Use refs from snapshot for clicks/typing
4. **Verify**: Re-run snapshot, check URL/text, or take screenshot
5. **Save**: Use `--screenshot-dir` to save directly into taskdoc `screenshots/`

## Screenshot Management

Save screenshots directly into the taskdoc directory when needed:
```bash
agent-browser screenshot --screenshot-dir docs/src/tasks/in-progress/<task>/screenshots
```

## Login Flow (Tachyon)

1. Open `http://localhost:16000`
2. Run `agent-browser snapshot -i`
3. Fill id=`test`, password=`hmw2atd@HCF3qwu*rcn`
4. Submit and wait for redirect
5. Verify the dashboard with snapshot, URL, or screenshot

## Notes

- Dev servers should already be running (`mise run dev`)
- No need to kill servers after testing
- Re-snapshot after every navigation or major DOM change
- If a command sequence does not depend on intermediate output, chaining with `&&` is fine
