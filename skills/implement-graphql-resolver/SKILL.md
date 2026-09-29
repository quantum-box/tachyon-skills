---
name: implement-graphql-resolver
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Proactively implement async-graphql resolver/mutation when GraphQL API needs to be added or
  modified. Use this skill when: (1) New GraphQL query or mutation is needed, (2) GraphQL type
  needs to be exposed, (3) Nested resolver for related data is required, (4) Task involves
  adding GraphQL API functionality. Schema is auto-generated - never edit schema.graphql
  directly.
---

# Implement GraphQL Resolver

async-graphqlを使用してGraphQLリゾルバーを実装する。

## Directory Structure

```
packages/{context}/src/interface_adapter/controller/
├── mod.rs                    # Export
├── resolver.rs               # Query resolvers (@Object impl)
├── mutation.rs               # Mutation resolvers (@Object impl)
└── model/
    ├── mod.rs                # Model export
    ├── objects.rs            # @SimpleObject types
    └── input.rs              # @InputObject types
```

## Query Resolver

```rust
#[derive(Default)]
pub struct {Context}Query;

#[Object]
impl {Context}Query {
    #[tracing::instrument(name = "{Context}Query::{method}", skip(self, ctx))]
    async fn {method}(
        &self,
        ctx: &Context<'_>,
        id: ID,
    ) -> Result<{OutputType}> {
        let app = ctx.data_unchecked::<Arc<crate::App>>();
        let executor = ctx.data_unchecked::<usecase::Executor>();
        let multi_tenancy = ctx.data_unchecked::<usecase::MultiTenancy>();

        let result = app
            .{usecase}()
            .execute(&usecase::{Usecase}InputData {
                executor,
                multi_tenancy,
                id: id.to_string().parse()?,
            })
            .await?;

        Ok(result.into())
    }
}
```

## Mutation Resolver

```rust
#[derive(Default)]
pub struct {Context}Mutation;

#[Object]
impl {Context}Mutation {
    #[tracing::instrument(skip(self, ctx))]
    async fn {method}(
        &self,
        ctx: &Context<'_>,
        input: {InputType},
    ) -> Result<{OutputType}> {
        let executor = ctx.data_unchecked::<usecase::Executor>();
        let multi_tenancy = ctx.data_unchecked::<usecase::MultiTenancy>();
        let app = ctx.data_unchecked::<Arc<crate::App>>();

        let result = app
            .{usecase}()
            .execute(&usecase::{Usecase}InputData {
                executor,
                multi_tenancy,
                field1: input.field1,
                field2: input.field2,
            })
            .await
            .map_err(|e| e.extend())?;

        Ok(result.into())
    }
}
```

## SimpleObject (Output Type)

```rust
#[derive(SimpleObject, Debug, Clone)]
pub struct {EntityName} {
    id: String,
    name: String,
    #[graphql(skip)]  // Exclude from schema
    internal_field: String,
    created_at: DateTime<Utc>,
}

impl From<domain::{Entity}> for {EntityName} {
    fn from(entity: domain::{Entity}) -> Self {
        Self {
            id: entity.id().to_string(),
            name: entity.name().to_string(),
            created_at: *entity.created_at(),
        }
    }
}
```

## InputObject (Input Type)

```rust
/// Input for creating entity
#[derive(Debug, Clone, InputObject)]
pub struct {Create}Input {
    /// Field description
    pub field1: String,
    /// Optional field
    pub field2: Option<String>,
}
```

**Important**: `Debug` trait is required for async-graphql.

## Error Handling

```rust
// Standard pattern
.map_err(|e| e.extend())?

// Handle 404 as None
match result {
    Ok(out) => Ok(Some(out.into())),
    Err(err) if err.is_not_found() => Ok(None),
    Err(err) => Err(err.extend())
}
```

## Important Rules

1. **Tracing required**: `#[tracing::instrument(skip(self, ctx))]`
2. **From impl for type conversion**: Domain type → GraphQL type
3. **Error extension**: Convert `errors::Error` with `.extend()`
4. **Doc comments become GraphQL docs**: Use `///` comments
5. **Schema is auto-generated**: Edit Rust code, then run `mise run codegen`
