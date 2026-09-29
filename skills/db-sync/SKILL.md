---
name: db-sync
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Run database migrations and seed data. Use proactively when: (1) Migration files
  added/modified. (2) Seed YAML files changed. (3) New auth actions added. (4) Database schema
  needs update. (5) User asks to sync database.
---

# DB Sync

Run migrations and seed data synchronization.

## Commands

```bash
# Run migrations
mise run docker-sqlx-migrate

# Apply seeds
yaml-seeder apply dev scripts/seeds/n1-seed

# Create new seed file
mise run seed-create -- NAME=new-feature
```

## Seed File Structure

Location: `scripts/seeds/n1-seed/`

Files are processed in alphabetical order:
```
001-auth-tenants.yaml
002-auth-service-accounts.yaml
003-iac-manifests.yaml  # dev-only IaC fixture; never production
...
008-auth-policies.yaml  # Actions and policies
```

## YAML Seed Format

```yaml
- table: schema_name.table_name
  rows:
    - column1: value1
      column2: value2
    - column1: value3
      column2: value4
```

## Adding New Auth Action

When adding new usecase with policy check:

1. Add to `008-auth-policies.yaml`:
```yaml
- table: tachyon_apps_auth.actions
  rows:
    - name: "context:ActionName"
      description: "What this action allows"

- table: tachyon_apps_auth.policy_actions
  rows:
    - policy_name: "relevant_policy"
      action_name: "context:ActionName"
```

2. Apply seeds:
```bash
yaml-seeder apply dev scripts/seeds/n1-seed
```

## TiDB Notes

- **DDL auto-commits**: Never mix DDL and DML in same migration
- **DDL/DML separation**: Migrations for schema, seeds for data
- **Low-traffic DDL**: Run DDL during low-load periods
- `003-iac-manifests.yaml` is only a local/dev fixture. It contains no Host
  config and no `auth-actions-sample` SeedData manifest. Production seeding
  rejects this file; platform manifest changes use the tenant-scoped API apply
  workflow instead.

## Workflow

1. Create migration if schema change needed
2. Run `mise run docker-sqlx-migrate`
3. Update seed files if data needed
4. Run `yaml-seeder apply dev scripts/seeds/n1-seed`
5. Verify with scenario tests
