---
name: codegen
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Run GraphQL code generation when a schema-affecting backend/frontend change or user request
  can make generated artifacts stale. Do not trigger for resolver edits that cannot change the
  schema.
---

# Codegen

Sync GraphQL schema and TypeScript types after backend or frontend changes.

## Command

```bash
mise run docker-codegen
```

This runs:
1. Rust → `schema.graphql` extraction
2. Frontend TypeScript type generation

## How It Works

### Backend (Rust → schema.graphql)

```rust
#[derive(SimpleObject)]
pub struct User {
    pub id: ID,
    pub name: String,
}

#[Object]
impl QueryResolver {
    async fn user(&self, id: ID) -> Result<Option<User>> { ... }
}
```

Generates `schema.graphql`:
```graphql
type User { id: ID!, name: String! }
type Query { user(id: ID!): User }
```

**Never edit schema.graphql directly** - it's auto-generated.

### Frontend (.graphql → TypeScript)

```graphql
# apps/tachyon/src/features/user/queries.graphql
query GetUser($id: ID!) {
  user(id: $id) { id name }
}
```

Generates `src/gen/graphql.ts`:
```typescript
export type GetUserQuery = { user?: { id: string; name: string } | null }
export const GetUserDocument = gql`...`
```

## Workflow

1. Modify Rust GraphQL code or frontend `.graphql` files
2. Run `mise run docker-codegen`
3. Verify no TypeScript errors
4. If errors: update `.graphql` queries to match new schema

## Common Scenarios

**Add field**: Add to Rust struct → codegen → update frontend queries → codegen

**Rename field**: Rename in Rust → codegen → update ALL frontend queries → codegen → `pnpm run ts`
