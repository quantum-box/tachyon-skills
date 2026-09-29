---
name: implement-repository
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Proactively implement repository pattern when database persistence layer is needed. Use this
  skill when: (1) New entity needs database storage, (2) CRUD operations for entity are
  required, (3) Database access layer needs to be added, (4) Task involves implementing
  SQLx-based persistence with Clean Architecture patterns.
---

# Implement Repository

Clean Architectureのリポジトリパターンに従ってリポジトリを実装する。

## Directory Structure

```
packages/{context}/
├── domain/src/
│   └── {entity}_repository.rs     # Trait definition
└── src/interface_adapter/gateway/
    └── sqlx_{entity}_repository.rs # SQLx implementation
```

## Domain Trait Definition

```rust
// packages/{context}/domain/src/{entity}_repository.rs

use async_trait::async_trait;
use errors::Result;

#[async_trait]
pub trait {Entity}Repository: Send + Sync + 'static {
    async fn save(&self, entity: &{Entity}) -> Result<()>;
    async fn find_by_id(&self, id: &{Entity}Id) -> Result<Option<{Entity}>>;
    async fn find_by_ids(&self, ids: &[{Entity}Id]) -> Result<Vec<{Entity}>>;
    async fn find_all(&self) -> Result<Vec<{Entity}>>;
    async fn find_by_tenant(&self, tenant_id: &TenantId) -> Result<Vec<{Entity}>>;
    async fn update(&self, entity: &{Entity}) -> Result<()>;
    async fn delete(&self, id: &{Entity}Id) -> Result<()>;
    async fn save_many(&self, entities: &[{Entity}]) -> Result<()>;
}
```

## Row Struct

```rust
#[derive(FromRow)]
struct {Entity}Row {
    id: String,
    tenant_id: String,
    name: String,
    description: Option<String>,
    // MySQL BOOLEAN returns i8, requires cast
    is_active: i8,  // use `as "is_active: bool"` in query
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

impl From<{Entity}Row> for {Entity} {
    fn from(row: {Entity}Row) -> Self {
        {Entity}::restore(
            row.id.parse().unwrap(),
            row.tenant_id.parse().unwrap(),
            row.name,
            row.description,
            row.is_active != 0,  // i8 -> bool
            row.created_at,
            row.updated_at,
        )
    }
}
```

## Repository Implementation

```rust
#[derive(Clone, Debug)]
pub struct Sqlx{Entity}Repository {
    pool: MySqlPool,
}

impl Sqlx{Entity}Repository {
    pub fn new(pool: MySqlPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl {Entity}Repository for Sqlx{Entity}Repository {
    #[tracing::instrument(skip(self), name = "Sqlx{Entity}Repository::save")]
    async fn save(&self, entity: &{Entity}) -> Result<()> {
        sqlx::query!(
            r#"
            INSERT INTO {table_name} (id, tenant_id, name, description, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                description = VALUES(description),
                is_active = VALUES(is_active),
                updated_at = VALUES(updated_at)
            "#,
            entity.id().to_string(),
            entity.tenant_id().to_string(),
            entity.name(),
            entity.description(),
            *entity.is_active(),
            *entity.created_at(),
            *entity.updated_at(),
        )
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn find_by_id(&self, id: &{Entity}Id) -> Result<Option<{Entity}>> {
        let row = sqlx::query_as!(
            {Entity}Row,
            r#"
            SELECT id, tenant_id, name, description,
                   is_active as "is_active: bool",
                   created_at, updated_at
            FROM {table_name}
            WHERE id = ?
            "#,
            id.to_string()
        )
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(Into::into))
    }
}
```

## Transaction Handling

```rust
async fn save_many(&self, entities: &[{Entity}]) -> Result<()> {
    let mut tx = self.pool.begin().await?;

    for entity in entities {
        sqlx::query!(
            r#"
            INSERT INTO {table_name} (id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
            "#,
            entity.id().to_string(),
            entity.name(),
            *entity.created_at(),
            *entity.updated_at(),
        )
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;
    Ok(())
}
```

## Important Rules

1. **SQLx online verification**: `SQLX_OFFLINE=true` is prohibited
2. **MySQL BOOLEAN is `i8`**: Use `as "column: bool"` for cast
3. **def_id! macro for ID types**: `def_id!({Entity}Id, "xx_");`
4. **Use `ok_or_else`**: Lazy evaluation for expensive error creation
5. **Trait requires `Send + Sync + 'static`**: For dynamic dispatch
6. **Add tracing**: `#[tracing::instrument(skip(self))]`
