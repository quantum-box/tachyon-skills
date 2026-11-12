---
name: tachyon-cli
description: |
  Use Tachyon CLI to set up auth profiles and inspect Tachyon Cloud Apps, builds, deployments, build logs, runtime logs, and live build status. Trigger when the user asks to check Tachyon CLI logs, Cloud App build status, Tachyon Build failures, app IDs, build IDs, or says "cliでログみて", "tachyon cli", "Cloud Appのログ", or similar.
---

# Tachyon CLI

Use this skill when inspecting Tachyon Platform state through the local
`tachyon` CLI. For writing `tachyon.yml`, setting env vars or secrets,
`tachyon compute apps apply`, triggering deploys, or filing user feedback,
install the skill that ships with the CLI and use it:

```bash
tachyon skills list
tachyon skills install tachyon-cloud --claude   # or --codex / --agents
```

## Core Rules

- Run the real CLI command when the user asks to check logs or build status.
- Check `tachyon <command> --help` before using an unfamiliar flag; the CLI
  changes faster than this skill.
- Treat tokens, API keys, auth headers, Cloudflare tokens, and generated
  secrets in logs as secrets. Do not echo them back; redact them in summaries.
- Prefer exact app IDs, build IDs, tenant IDs, PR URLs, and issue context
  already provided by the user. If the user provides a Cloud App URL or GitHub
  check URL, extract the app ID / tenant ID from it and start there.
- Do not assume the active profile tenant is correct. Pass `--tenant-id`
  explicitly when the tenant is known.
- A token refresh message is fine to mention; the token value is not.

## Storage Integration Routing

For file attachments, photo uploads, direct R2 build commands, or R2
authentication failures, read [tachyon-storage](../tachyon-storage/SKILL.md).
Check whether the app should use Tachyon Storage before proposing broader
Cloudflare token permissions. Keep build success separate from working
attachment upload/read.

## Initial Setup (First-Time Use)

Make sure an auth profile exists:

```bash
tachyon auth list
```

If none is listed, log in. Without `--profile`, the CLI uses the active
profile or creates `default`:

```bash
tachyon auth login
# When the browser runs on another machine (SSH, containers, a VPS):
tachyon auth login --no-browser
```

`--no-browser` prints a login URL and a code instead of waiting on a local
callback port. Then resolve which tenants the profile can act on instead of
guessing an ID:

```bash
tachyon org operators list --json
```

When a script needs the user's API token, read it from a pipe; the command
refreshes a token that is about to expire and refuses to print to a terminal:

```bash
TOKEN="$(tachyon auth token)"
```

## Quick Orientation

```bash
tachyon --version
tachyon compute --help
tachyon compute apps list --tenant-id <tenant_id>
```

## Build Status Workflow

1. Identify the target (app ID like `app_01...`, build ID like `bld_01...`,
   tenant ID like `tn_01...`).
2. Show recent builds:

   ```bash
   tachyon compute status <app_id_or_name> --tenant-id <tenant_id>
   ```

3. Fetch the latest build log, or a specific one:

   ```bash
   tachyon compute logs <app_id_or_name> --tenant-id <tenant_id>
   tachyon compute logs --build-id <build_id> --tenant-id <tenant_id>
   ```

   Add `--agent` for compact JSON Lines that are easier to summarize.

4. Follow a running build until it finishes (exits 1 when the build fails):

   ```bash
   tachyon compute builds watch <app_id_or_name> --tenant-id <tenant_id>
   ```

5. Tail runtime logs of a Cloudflare-backed app:

   ```bash
   tachyon compute logs --tail <app_id> --tenant-id <tenant_id>
   ```

`tachyon compute builds reproduce` rebuilds a cloud build locally in Docker
when the log alone does not explain a failure.

## What To Report

- Latest build ID, status, branch, commit, and created time.
- Whether the failure mode is still present or fixed.
- The failing command and error line, not the whole log.
- Deploy result and deployment URL if present.

Do not paste full raw logs unless the user explicitly asks. Even then, redact
patterns such as `CLOUDFLARE_API_TOKEN=...`, `TACHYON_AUTH_TOKEN=...`,
`Authorization: Bearer ...`, `--auth-token ...`, API keys, client secrets,
GitHub tokens, AWS secrets, and signed URLs (`<redacted>`).

## Final Response

Keep the answer short and operational:

- Say whether the target is actually passing or failing now.
- Include the latest successful or failed build ID.
- Include the exact command family used.
- Call out residual risk, such as a GitHub PR status check still showing an
  older failed build even though newer CLI builds succeeded.
