---
name: check-ci
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Inspect GitHub Actions status for the current branch when the user asks about CI, a PR needs a
  status check, or an explicit CI verification is requested. Read-only by default; diagnose or
  fix failures only when the user asks.
---

# Check CI

Check GitHub Actions workflow status for the current branch.

By default this skill is read-only. Do not modify files, commit, push, or start
an automatic fix loop after `git push` or PR creation. If the user explicitly
asks to fix CI, inspect the failed job first and limit changes to the reported
failure.

## Quick Check

```bash
# List recent workflow runs for current branch
gh run list --branch $(git branch --show-current) --limit 5

# Check for failures only
gh run list --branch $(git branch --show-current) --limit 10 --json status,conclusion,name,databaseId | jq '[.[] | select(.conclusion == "failure" or .status == "in_progress")]'
```

## View Failed Logs

```bash
# Get failed run details
gh run view <run_id> --log-failed | tail -100
```

## Common Workflow Names

| Workflow | Description |
|----------|-------------|
| `tachyon ci` | tachyon frontend checks |
| `Rust` | Rust cargo check, clippy, test |

## Fix Common Issues (explicit request only)

### Lint Errors
```bash
pnpm exec turbo run lint --filter=<app>         # Check lint
pnpm exec turbo run format:write --filter=<app> # Auto-fix format
```

### TypeScript Errors
```bash
pnpm exec turbo run ts --filter=<app>
```

### Rust Errors
```bash
mise run docker-check   # cargo check + clippy
mise run docker-fmt     # cargo fmt
```

## After Fixing

1. Apply only the requested, minimal fix.
2. Ask before committing or pushing unless that action was explicitly requested.
3. Re-run the relevant status check and report any remaining failures.
