---
name: implement-domain-entity
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Proactively implement domain entity or value object when new domain model is needed. Use this
  skill when: (1) New entity with identity is required, (2) Value object for domain concept is
  needed, (3) Domain model for new feature is being designed, (4) Task involves DDD entity/value
  object implementation with def_id! macro and immutable update patterns.
---

# Implement Domain Entity

ドメイン駆動設計に従ってエンティティと値オブジェクトを実装する。

## Directory Structure

```
packages/{context}/domain/src/
├── mod.rs                    # Export
├── {entity}.rs               # Entity definition
├── {entity}_repository.rs    # Repository trait
└── service/
    └── {service_name}.rs     # Domain service
```

## ID Type Definition with def_id! Macro

```rust
use util::macros::*;

def_id!({Entity}Id, "{prefix}_");

// Examples
def_id!(ProductId, "pd_");
def_id!(PolicyId, "pol_");
def_id!(ActionId, "act_");
def_id!(ChatRoomId, "ch_");
```

**Features**:
- Auto-generates prefix + ULID (lowercase)
- `Default::default()` generates new ID
- `to_string()` for serialization
- `parse::<{Entity}Id>()` for parsing
- 29 characters (prefix + 24-char ULID)

## Entity Basic Structure

```rust
use chrono::{DateTime, Utc};
use derive_getters::Getters;
use util::macros::*;
use value_object::TenantId;

def_id!({Entity}Id, "{prefix}_");

/// Entity description
#[derive(Debug, Clone, Getters)]
pub struct {Entity} {
    id: {Entity}Id,
    tenant_id: TenantId,
    name: String,
    description: Option<String>,
    status: {Entity}Status,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}
```

## Constructor Pattern

```rust
impl {Entity} {
    /// Create new (auto-generate ID)
    pub fn new(
        tenant_id: TenantId,
        name: String,
        description: Option<String>,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: {Entity}Id::default(),
            tenant_id,
            name,
            description,
            status: {Entity}Status::Active,
            created_at: now,
            updated_at: now,
        }
    }

    /// Restore from DB (specify ID)
    pub fn restore(
        id: {Entity}Id,
        tenant_id: TenantId,
        name: String,
        description: Option<String>,
        status: {Entity}Status,
        created_at: DateTime<Utc>,
        updated_at: DateTime<Utc>,
    ) -> Self {
        Self {
            id,
            tenant_id,
            name,
            description,
            status,
            created_at,
            updated_at,
        }
    }
}
```

## Immutable Update Pattern

```rust
impl {Entity} {
    /// Update (returns new instance)
    pub fn update(self, name: Option<String>, description: Option<String>) -> Self {
        Self {
            name: name.unwrap_or(self.name),
            description: description.or(self.description),
            updated_at: Utc::now(),
            ..self
        }
    }

    pub fn activate(self) -> Self {
        Self {
            status: {Entity}Status::Active,
            updated_at: Utc::now(),
            ..self
        }
    }

    pub fn deactivate(self) -> Self {
        Self {
            status: {Entity}Status::Inactive,
            updated_at: Utc::now(),
            ..self
        }
    }
}
```

## Enum Type

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "async-graphql", derive(async_graphql::Enum))]
pub enum {Entity}Status {
    Active,
    Inactive,
    Pending,
    Archived,
}

impl FromStr for {Entity}Status {
    type Err = errors::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "active" => Ok(Self::Active),
            "inactive" => Ok(Self::Inactive),
            "pending" => Ok(Self::Pending),
            "archived" => Ok(Self::Archived),
            _ => Err(errors::Error::type_error(format!("Invalid status: {}", s))),
        }
    }
}
```

## mod.rs Export

```rust
mod {entity};
mod {entity}_repository;

pub use {entity}::{Entity}, {Entity}Id, {Entity}Status;
pub use {entity}_repository::{Entity}Repository;
```

## Important Rules

1. **def_id! macro for ID types**: Prefix + ULID
2. **Getters auto-generation**: `#[derive(Getters)]`
3. **Immutable design**: `update()` returns new instance
4. **restore for DB recovery**: Complete restoration with ID
5. **new for creation**: Auto-generate ID and timestamps
6. **FromStr implementation**: Support string parsing
7. **Business logic in entity**: Encode domain rules as methods
