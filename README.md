# Tachyon Skills

Codex and Claude Code plugin for Tachyon agent workflows: remote browser control (k3s Cloudflare Mesh CDP gateway), Tachyon CLI Cloud App/build/log inspection, Linear issue management, Sentry issue operations, and Slack notification checks.

Split out from the private [`quantum-box/agent-packages`](https://github.com/quantum-box/agent-packages) repository's `plugins/tachyon` so it can be distributed publicly without requiring organization credentials.

## Skills

- `tachyon-browser`: use the Tachyon k3s Cloudflare Mesh remote Chromium CDP gateway with agent-browser, Playwright, Codex, or Claude Code.
- `tachyon-cli`: inspect Tachyon Cloud Apps, builds, deployments, build logs, auth profiles, and live build status.
- `tachyon-linear`: manage Linear issues through Tachyon's project-management integration.
- `tachyon-sentry`: inspect and manage Sentry issues through Tachyon's tenant-scoped operations API.
- `tachyon-slack-notify`: verify and send Slack notifications through the Tachyon CLI, collect thread replies, and react to them.

## Requirements

- The [Tachyon CLI](https://github.com/quantum-box/tachyon-sdk) installed and on `PATH`.
- A Tachyon auth profile. If you have not logged in yet, see the "Initial Setup" section of the `tachyon-cli` skill (`tachyon auth login`).
- Access to your own Tachyon tenant(s) — this plugin does not ship any tenant IDs or credentials.

## Install

### Claude Code

```text
/plugin marketplace add quantum-box/tachyon-skills
/plugin install tachyon@tachyon-skills
/reload-plugins
```

For local development:

```bash
claude --plugin-dir .
```

This exposes `/tachyon:tachyon-browser`, `/tachyon:tachyon-cli`, `/tachyon:tachyon-linear`, `/tachyon:tachyon-sentry`, and `/tachyon:tachyon-slack-notify`. It also adds `remote-browser` to the Bash PATH while enabled.

### Codex app

1. Open **Settings** in the Codex app (`Cmd+,`).
2. Select **Plugins**, then open the **Marketplace** tab.
3. Click **Add plugin marketplace**.
4. Enter `quantum-box/tachyon-skills` in **Source**. Leave **Git ref** and **Sparse paths** empty, then click **Add marketplace**.
5. Open the **Plugins** tab, search for `tachyon`, open it, and click **Install plugin**.

For local development, enter the absolute path to this repository in **Source** instead of `quantum-box/tachyon-skills`. If an added marketplace or plugin does not appear immediately, click **Refresh** and start a new task.

### Codex CLI

```bash
codex plugin marketplace add quantum-box/tachyon-skills
codex plugin add tachyon@tachyon-skills
```

For local development, from this repository root:

```bash
codex plugin marketplace add .
codex plugin add tachyon@tachyon-skills
```
