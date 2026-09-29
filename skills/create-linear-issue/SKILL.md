---
name: create-linear-issue
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Create Linear issues for this tachyon-apps repository through the Tachyon CLI. Use when the
  user asks to create a Linear issue, ticket, follow-up, task, bug, verification issue, 動作確認
  issue, or repo task. Always use `tachyon issue create` or `tachyon pm issue create`, never
  GitHub Issues, and default to the PLT / プラットフォーム事業 team for this repository.
---

# Create Linear Issue

## Overview

Create Linear issues for `quantum-box/tachyon-apps` through the Tachyon PM issue abstraction. The daily command is `tachyon issue ...`; the canonical command is `tachyon pm issue ...`.

## Defaults

- Provider: `linear`
- Team: `PLT` (`プラットフォーム事業`)
- Tenant: use an explicit tenant from the user's URL or request. If none is provided, discover accessible tenants with `tachyon org operators list --json` and select one for the active profile; ask the user if no suitable tenant is available.
- Priority: infer from impact. Use `urgent` for active production breakage, `high` for production/runtime verification or deploy blockers, `medium` for normal follow-ups, `low` for cleanup, and `none` only when priority is intentionally absent.
- JSON output: pass `--json` and summarize the returned issue key and URL.

## Workflow

1. Do not create or edit GitHub Issues unless the user explicitly asks for GitHub.
2. Prefer the short Tachyon CLI entrypoint:

   ```bash
   tachyon issue create \
     --tenant-id <tenant_id> \
     --provider linear \
     --team PLT \
     --title "<title>" \
     --description "<markdown description>" \
     --priority <urgent|high|medium|low|none> \
     --json
   ```

3. Use `tachyon pm issue create` when the user specifically asks for the canonical PM command or when verifying that the alias and canonical path both work.
4. Use `--skip-if-exists` only for smoke tests, retries, or explicit duplicate avoidance. If the user says to create a new issue, omit `--skip-if-exists`.
5. Write titles in Japanese or mixed Japanese/English matching the user's wording. Prefix with a domain only when useful, for example `[Cloud Apps]`, `[TxCloud]`, or `[RECONCILE-E]`.
6. Write concise Markdown descriptions with:
   - Background
   - Scope or target
   - Acceptance Criteria
   - Notes or links
7. Return the Linear key and URL only after creation or update succeeds.

## Useful Commands

List recent issues before creating when duplicate risk is high:

```bash
tachyon issue list \
  --tenant-id <tenant_id> \
  --provider linear \
  --team PLT \
  --json
```

Update an issue when the user asks to change status, title, assignee, or priority:

```bash
tachyon issue update <issue-key> \
  --tenant-id <tenant_id> \
  --provider linear \
  --team PLT \
  --status "<status>" \
  --json
```

Common statuses observed for PLT include `Backlog`, `Todo`, `In Progress`, `Done`, `Canceled`, and `Duplicate`. Use the user's requested status spelling first, then retry with the PLT spelling if Linear rejects it.

## Reconnect Handling

If `create` fails with a Linear error like `Invalid scope: write or issues:create required`, the Tachyon connection is active but the stored Linear OAuth token is read-only.

- Do not treat this as a code failure after the write-scope release.
- Ask the user to use the Linear integration `Reconnect` action, or perform reconnect only when the user explicitly asks for it.
- After reconnect, rerun `tachyon issue create`.
- Do not print OAuth access tokens, refresh tokens, API keys, or signed callback states. It is fine to report that the OAuth URL requested `read,write`.

## Reporting

Keep the final response short:

- Say which command family was used.
- Include the issue key, URL, status, and priority.
- Mention whether the issue was newly created or reused via `--skip-if-exists`.
