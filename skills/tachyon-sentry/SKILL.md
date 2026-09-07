---
name: tachyon-sentry
description: Use Tachyon CLI to inspect and manage Sentry issues through Tachyon's tenant-scoped operations API. Trigger when the user asks to list unresolved Sentry issues, inspect issue details, resolve or assign an issue, verify Sentry connectivity, says "Sentry見て", "Sentryのエラー確認", "tachyon ops sentry", or explicitly wants Sentry access through the Tachyon CLI instead of the Sentry API or UI.
---

# Tachyon Sentry

Use the local `tachyon` CLI for Sentry issue operations.

## Rules

- Use `tachyon ops sentry issues ...`; do not bypass Tachyon with direct Sentry API calls.
- Pass an explicit `--tenant-id` and `--profile` when known. Do not assume the active profile has the correct tenant.
- Add `--platform-id` whenever the tenant is reached through a parent platform rather than direct membership. The ops tenant that holds the Sentry token is always in that position, so every command scoped to it needs the flag.
- Address an issue by the numeric Sentry issue `id`. The human-readable short ID (for example `MYPROJECT-1A2`) is rejected by `view`, `resolve`, and `assign`.
- Add `--json` so results can be parsed and summarized accurately.
- Treat access tokens, auth headers, secret references, DSNs, and credential refresh output as secrets. Never echo them.
- Default to read-only `list` and `view` operations.
- Run `resolve` or `assign` only when the user explicitly requests the mutation and the issue ID is unambiguous. For assignment, require the exact Sentry user ID, username, or email.
- Archiving (Sentry's `ignored` state) has no CLI or API surface. Use the Sentry UI or an authorized Sentry MCP connector instead, and say which one you used.
- Scope a failing mutation correctly with `--platform-id`; never swap in another tenant's credentials, a host token, or a direct Sentry API call to get around the failure.

## Orientation

Confirm the installed CLI and available subcommands:

```bash
command -v tachyon
tachyon --version
tachyon ops sentry issues --help
```

If authentication or tenant selection is unclear, inspect profiles without exposing credentials:

```bash
tachyon auth list
```

## List Issues

List unresolved issues for a project:

```bash
tachyon ops sentry issues list \
  --project <project_slug_or_id> \
  --query 'is:unresolved' \
  --limit 20 \
  --tenant-id <tenant_id_or_alias> \
  --platform-id <platform_id> \
  --profile <profile> \
  --json
```

Use the Sentry project slug directly with `--project`; do not rewrite it into the search query.

A wrong but plausible slug is not an error. The CLI prints `No Sentry issues found.` and exits 0, so an empty list means either "no issues" or "wrong slug". Confirm the slug before reporting that a project is clean.

`list` is the only way to obtain the numeric `id` that every other subcommand needs. Keep both `id` and `short_id` from the response: `short_id` is what humans recognize, `id` is what the CLI accepts.

Report the relevant issue ID or short ID, title, status, count, last-seen time, and permalink. Avoid dumping large raw responses unless requested.

## View an Issue

Fetch one issue by numeric Sentry issue ID:

```bash
tachyon ops sentry issues view <numeric_issue_id> \
  --tenant-id <tenant_id_or_alias> \
  --platform-id <platform_id> \
  --profile <profile> \
  --json
```

The numeric `id` from `list` is required. Passing a short ID returns `404 NotFoundError: Sentry issue resource was not found`, which looks like a missing issue but only means the identifier was the wrong kind.

## Resolve an Issue

After explicit user confirmation:

```bash
tachyon ops sentry issues resolve <numeric_issue_id> \
  --tenant-id <ops_tenant_id> \
  --platform-id <platform_id> \
  --profile <profile> \
  --json
```

Verify the returned status is `resolved`.

Mutations run against the tenant that holds the write-capable Sentry token, which is normally the ops (system) tenant rather than the tenant whose app produced the error. That tenant is reached through a parent platform, so `--platform-id` is mandatory here even when reads succeeded without it. A read-only OAuth connection is not sufficient for mutations.

## Assign an Issue

After the user provides the exact assignee:

```bash
tachyon ops sentry issues assign <numeric_issue_id> <user_id_username_or_email> \
  --tenant-id <ops_tenant_id> \
  --platform-id <platform_id> \
  --profile <profile> \
  --json
```

Verify the returned `assigned_to` field and report the assignee without exposing other account data.

## Troubleshooting

- `401 Operator is not registered and no validated platform scope is available`: the tenant is reached through a parent platform and `--platform-id` was missing. Add it rather than switching tenants or profiles.
- Other `401`: refresh or repair the selected Tachyon auth profile; do not request or print raw tokens.
- `403` on `list` or `view`: verify the tenant's Sentry connection and read scopes.
- `404 Sentry issue resource was not found` on `view`, `resolve`, or `assign`: almost always a short ID where the numeric `id` was required. Re-run `list` and take `id` from the response before concluding the issue is gone.
- `404 A tenant-scoped Sentry write token is not configured` on `resolve` or `assign`: the selected tenant has no write token. Scope the command to the ops tenant with `--platform-id`. Do not fall back to another tenant's credentials or a host token.
- Other `404`: verify the project slug, tenant, and profile. The backend handles a stale organization slug when the token exposes exactly one organization.
- Multiple accessible Sentry organizations: reconnect with an explicit organization instead of guessing.

## Final Response

Keep the result operational:

- State whether the CLI operation succeeded.
- Include the explicit tenant, profile name, project, and command family used.
- For reads, summarize matching issues and whether `view` also succeeded.
- For mutations, state exactly what changed.
- Separate CLI proof from deployment or browser proof when those were not checked.
