---
name: tachyon-linear
description: Use Tachyon CLI to manage Linear issues through Tachyon's project-management integration. Trigger when the user asks to create, list, search, update, assign, prioritize, comment on, relate, or move Linear issues with the Tachyon CLI, says "tachyon cliでlinear", "linear issue", "Linear作って", "Linear更新", or asks to avoid GitHub issues and use Linear instead.
---

# Tachyon Linear

Use this skill when operating Linear through the local `tachyon` CLI.

## Rules

- Use the real `tachyon` CLI. Do not use direct Linear API calls or GitHub issues.
- `tachyon linear issue ...` and `tachyon issue ... --provider linear` take the same options; `tachyon issue` uses the tenant's default project-management provider. Follow the repository's own convention when it names one.
- For mutations, confirm the exact title, description, team, status, priority, assignee, and due date unless the user already provided them clearly.
- Always pass an explicit `--tenant-id` when the tenant/operator is known from the task, URL, repo, or user context.
- Pass the team the user or repository names. If none is given, list teams with `tachyon linear team list --tenant-id <tenant> --json` and ask; do not guess.
- **Delegation:** `create` and `update` automatically delegate the issue to the Linear agent unless told otherwise. Pass `--no-delegate` (or `--delegate-id ""` on create) when the user wants the issue unassigned or assigned to a person, and say which you chose.
- Use `--json` when creating, listing, or updating so the result can be parsed and summarized accurately.
- Treat API tokens, auth headers, and credential refresh output as secrets. Do not echo them back.

## Orientation

Check CLI availability and auth before doing live work, and read a subcommand's `--help` before using an unfamiliar field:

```bash
command -v tachyon
tachyon auth list
tachyon linear issue --help
tachyon linear issue create --help
```

## List And Read

```bash
tachyon linear issue list \
  --team "<team key or name>" \
  --tenant-id <tenant_id_or_alias> \
  --json
```

- `--include-completed` includes completed or canceled issues.
- Results are paged (`--limit` up to 100, `--cursor`); `--all` follows every page.
- `--project <id or name>` filters by project.

```bash
tachyon linear issue get ABC-123 --tenant-id <tenant> --json
tachyon linear issue children ABC-123 --tenant-id <tenant> --json
```

## Create

```bash
tachyon linear issue create \
  --team "<team key or name>" \
  --title "<issue title>" \
  --description "<markdown description>" \
  --priority medium \
  --tenant-id <tenant_id_or_alias> \
  --json
```

- `--skip-if-exists` returns an existing issue with the same title instead of creating one; use it for idempotent follow-ups and retries, not when the user asked for a new issue.
- `--parent <id or key>` creates a sub-issue.
- Other options: `--assignee <id>`, `--label-id <id>` (repeatable), `--project <id or name>`, `--due-date YYYY-MM-DD`, `--related-issue-id <id>` (repeatable), `--cycle-id`, `--project-milestone-id`.

## Update

```bash
tachyon linear issue update ABC-123 \
  --team "<team key or name>" \
  --status "In Progress" \
  --priority high \
  --tenant-id <tenant_id_or_alias> \
  --json
```

- `--team` is required when `--status` is a name; use `--status-id` otherwise.
- Labels: `--label-id` replaces all labels; `--add-label-id` / `--remove-label-id` change one.
- `--parent <id>` moves the issue under a parent; `--remove-parent` promotes it to top level.

## Comments And Relations

```bash
tachyon linear issue comment create ABC-123 --body "<markdown>" --tenant-id <tenant> --json
tachyon linear issue comment list ABC-123 --tenant-id <tenant> --json
tachyon linear issue relation create ABC-123 ABC-456 --relation-type related --tenant-id <tenant> --json
tachyon linear issue relation list ABC-123 --tenant-id <tenant> --json
```

Check `--relation-type` values with `tachyon linear issue relation create --help` before using a type other than `related`.

## Reporting

Keep the user-facing result short and operational:

- For create: include the Linear key, title, team, URL if returned, delegation choice, and whether `--skip-if-exists` reused an existing issue.
- For list: include the matching issue keys, titles, statuses, assignees, and dates relevant to the request.
- For update: include the issue key and changed fields.
- Mention the exact command family used, for example `tachyon linear issue create`.
