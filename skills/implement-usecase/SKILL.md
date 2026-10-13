---
name: implement-usecase
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Proactively implement Clean Architecture Usecase when new business logic or feature
  implementation is needed. Use this skill when: (1) New feature requires business logic
  implementation, (2) API endpoint needs backend logic, (3) New operation like
  create/update/delete is being added, (4) Task involves implementing core application
  functionality. This skill provides the InputData/InputPort/OutputData pattern with policy
  checks.
---

# Implement Usecase

Clean Architectureパターンに従ってUsecaseを実装する。

## Directory Structure

```
packages/{context}/src/usecase/
├── mod.rs                    # Export
├── {usecase_name}.rs         # Usecase implementation
└── {usecase_name}/
    ├── mod.rs                # For complex usecases
    ├── input.rs
    └── output.rs
```

## InputData Structure

```rust
use usecase::{Executor, MultiTenancy, UsecaseInputData};

#[derive(Debug)]
pub struct {Usecase}InputData<'a> {
    pub executor: &'a Executor,
    pub multi_tenancy: &'a MultiTenancy,
    /// External input with a format rule: take the value object / enum.
    pub name: ProjectName,
    pub visibility: Option<Visibility>,
    /// Free text or opaque IDs without a rule may stay `String`.
    pub description: Option<String>,
}

impl UsecaseInputData for {Usecase}InputData<'_> {
    fn executor(&self) -> &Executor {
        self.executor
    }
    fn multi_tenancy(&self) -> &MultiTenancy {
        self.multi_tenancy
    }
}
```

### Input value objects ([ADR-0147](https://github.com/quantum-box/tachyon-apps/blob/main/docs/src/architecture/decisions/ADR-0147-usecase-input-value-objects.md))

- Single-field rules (length, format, allowed values, numeric range) live in
  the value object, not in the usecase. Define string VOs with
  `value_object::validated_string_value_object!` (see its rustdoc) and enums
  with `FromStr` + serde + `utoipa::ToSchema`.
- Do not add `fn validate_*` helpers or `match input.as_deref() { Some("..") }`
  parsing to usecases. Keep only cross-field, collection, and external-state
  checks there.
- The boundary builds the value: REST DTO fields are VOs extracted with
  `errors::axum::ValidatedJson`, MCP args use `param_vo` / `param_vo_opt`,
  GraphQL resolvers parse with `.parse::<Vo>()?`. `param_vo` /
  `param_vo_opt` read JSON strings only (a non-string value is
  `invalid_params`); for a numeric VO, read the number and call its
  `try_new`.
- A numeric VO placed in a REST DTO must validate in `Deserialize`
  (`#[serde(try_from = "u32")]` with `TryFrom` calling `try_new`). A derived
  `Deserialize` on the tuple field skips the range rule; until a VO has one,
  keep the DTO field primitive and call `try_new` in the handler.
- Contract crates such as `aip_contract` stay string-typed. The handler parses
  their fields into VOs before building the usecase input.

## InputPort Trait Implementation

```rust
use async_trait::async_trait;
use errors::Result;
use usecase::InputPort;

#[async_trait]
impl<'a> InputPort<{Usecase}InputData<'a>> for {Usecase} {
    type Output = {Usecase}OutputData;

    #[tracing::instrument(skip(self, input), name = "{Usecase}::execute")]
    async fn execute(&self, input: &{Usecase}InputData<'a>) -> Result<Self::Output> {
        // 1. Policy check
        self.policy_check("{context}:{ActionName}", input).await?;

        // 2. Resolve tenant
        let tenant_id = input.multi_tenancy.get_operator_id()?;

        // 3. Business logic
        let entity = self.repository.find_by_id(&input.id).await?
            .ok_or_else(|| errors::Error::not_found("Entity not found"))?;

        // 4. Return output
        Ok({Usecase}OutputData { entity })
    }
}
```

## Usecase Struct

```rust
use std::sync::Arc;
use usecase::CheckPolicy;
use usecase_policy_macros::usecase;

#[usecase(write)]
pub struct {Usecase} {
    auth_app: Arc<dyn usecase::AuthApp>,
    repository: Arc<dyn {Entity}Repository>,
}

impl CheckPolicy for {Usecase} {
    fn auth_app(&self) -> &Arc<dyn usecase::AuthApp> {
        &self.auth_app
    }
}

impl {Usecase} {
    pub fn new(
        auth_app: Arc<dyn usecase::AuthApp>,
        repository: Arc<dyn {Entity}Repository>,
    ) -> Self {
        Self { auth_app, repository }
    }
}
```

## OutputData

```rust
#[derive(Debug)]
pub struct {Usecase}OutputData {
    pub entity: {Entity},
}
```

## Important Rules

1. **1 Usecase = 1 public method**: Only `execute` is public
2. **Usecase naming**: Use verbs (`CreateUser`, `UpdateProduct`, `DeleteOrder`)
3. **No Usecase suffix**: Use `CreateUser`, not `CreateUserUsecase`
4. **Policy check first**: Always call `self.policy_check()` at the beginning
5. **Readability**: Avoid unnecessary `map_err` - `errors::Result` propagates automatically
6. **Tracing**: Always add `#[tracing::instrument]`
7. **Usecase policy manifest**: External usecases that perform policy checks must have `#[usecase(read)]`, `#[usecase(write)]`, or `#[usecase(admin)]`.
   - Default action is `{context}:{StructName}`.
   - `context` is inferred from the crate/package name.
   - Use `#[usecase(write, action = "auth:UpdatePolicy")]` only for existing compatibility exceptions.
   - Do not add `kind` or `internal`; internal application helpers should stay private methods/services and are not manifest entries.
   - After adding or changing annotations, run `mise run usecase-policy-prepare` and `mise run usecase-policy-check`.
8. **Value object input**: External input with a rule arrives as a VO/enum; no single-field validation in the usecase (ADR-0147)

## mod.rs Export

```rust
mod {usecase_name};
pub use {usecase_name}::{Usecase}, {Usecase}InputData, {Usecase}OutputData;
```
