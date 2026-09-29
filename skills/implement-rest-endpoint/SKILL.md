---
name: implement-rest-endpoint
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Proactively implement axum REST endpoint when REST API needs to be added. Use this skill when:
  (1) New REST endpoint is required, (2) HTTP handler needs implementation, (3) OpenAPI
  documentation is needed for endpoint, (4) Task involves adding REST API functionality with
  utoipa annotations.
---

# Implement REST Endpoint

axumを使用してREST APIエンドポイントを実装する。

## Directory Structure

```
packages/{context}/src/adapter/axum/
├── mod.rs                    # create_router() definition
├── {endpoint}_handler.rs     # Handler implementation
├── model.rs                  # Request/Response types
├── error.rs                  # Custom error types (if needed)
└── openapi.rs                # OpenAPI definition (with utoipa)
```

## Router Definition (mod.rs)

```rust
use axum::{routing::{get, post}, Router, Extension};

pub fn create_router() -> Router {
    Router::new()
        .route("/v1/{context}/{endpoint}", post({endpoint}_handler::create))
        .route("/v1/{context}/{endpoint}", get({endpoint}_handler::list))
        .route("/v1/{context}/{endpoint}/:id", get({endpoint}_handler::get))
        .route("/v1/{context}/{endpoint}/:id", patch({endpoint}_handler::update))
        .route("/v1/{context}/{endpoint}/:id", delete({endpoint}_handler::delete))
}

// With dependency injection
pub fn create_router_with_deps(
    usecase: Arc<{Usecase}>,
) -> Router {
    Router::new()
        .route("/v1/{context}/{endpoint}", post(handler::create))
        .layer(Extension(usecase))
}
```

## Handler Implementation

```rust
#[utoipa::path(
    post,
    path = "/v1/{context}/{endpoint}",
    request_body = {Request}Request,
    responses(
        (status = 201, description = "Created successfully", body = {Response}Response),
        (status = 400, description = "Bad request"),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
    ),
    tag = "{context}"
)]
#[tracing::instrument(skip(usecase, executor, multi_tenancy))]
#[axum::debug_handler]
pub async fn create(
    executor: Executor,
    multi_tenancy: MultiTenancy,
    Extension(usecase): Extension<Arc<{Usecase}>>,
    Json(request): Json<{Request}Request>,
) -> Result<(StatusCode, Json<{Response}Response>)> {
    let operator_id = resolve_tenant_id(&executor, &multi_tenancy)?;

    let result = usecase
        .execute({Usecase}InputData {
            field1: request.field1,
            field2: request.field2,
        })
        .await?;

    Ok((StatusCode::CREATED, Json(result.into())))
}
```

## Request/Response Types

```rust
#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateRequest {
    pub name: String,
    pub description: Option<String>,
    #[serde(default)]
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct EntityResponse {
    pub id: String,
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    pub created_at: String,
}

impl From<DomainEntity> for EntityResponse {
    fn from(entity: DomainEntity) -> Self {
        Self {
            id: entity.id().to_string(),
            name: entity.name().to_string(),
            description: entity.description().clone(),
            created_at: entity.created_at().to_rfc3339(),
        }
    }
}
```

## Required Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <token>` (use `dummy-token` in dev) |
| `x-operator-id` | Yes | Tenant ID (`tn_xxxxx`) |
| `x-platform-id` | No | Platform ID |
| `x-user-id` | No | User ID (seed user applied if omitted in dev) |

## Important Rules

1. **`#[axum::debug_handler]`**: Shows detailed argument parsing errors
2. **`#[tracing::instrument]` with skip**: Exclude large objects
3. **Errors auto-convert**: `errors::Error` implements `IntoResponse`
4. **Explicit StatusCode**: POST=201, GET=200, DELETE=204
5. **OpenAPI annotations**: Use `#[utoipa::path]` macro
