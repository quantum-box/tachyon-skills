---
name: create-usecase
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Create a new Clean Architecture usecase when the task explicitly needs a new
  usecase/application operation or the user asks. Do not trigger for every business-logic edit.
---

# Create Usecase

Generate Clean Architecture usecase following project conventions.

## Structure

```
packages/{context}/src/usecase/{action_name}.rs
```

## Template

```rust
use crate::usecase::boundary::{UsecaseInputData, UsecaseOutputData};
use auth::policy::MultiTenancyAction;
use auth::{Executor, MultiTenancy};
use errors::Result;

#[derive(Debug, Clone)]
pub struct InputData<'a> {
    pub executor: Executor,
    pub multi_tenancy: MultiTenancy,
    // Add fields here
    pub name: &'a str,
}

impl UsecaseInputData for InputData<'_> {
    fn executor(&self) -> &Executor {
        &self.executor
    }
    fn multi_tenancy(&self) -> &MultiTenancy {
        &self.multi_tenancy
    }
}

#[derive(Debug, Clone)]
pub struct OutputData {
    // Add output fields
    pub id: String,
}

impl UsecaseOutputData for OutputData {}

#[async_trait::async_trait]
pub trait InputPort: Send + Sync {
    async fn execute(&self, input: &InputData<'_>) -> Result<OutputData>;
}

pub struct Interactor {
    // Add repositories
    repo: Arc<dyn SomeRepository>,
    auth_app: Arc<auth::App>,
}

impl Interactor {
    pub fn new(repo: Arc<dyn SomeRepository>, auth_app: Arc<auth::App>) -> Self {
        Self { repo, auth_app }
    }

    async fn policy_check(
        &self,
        executor: &Executor,
        multi_tenancy: &MultiTenancy,
        resource_id: Option<&str>,
    ) -> Result<()> {
        self.auth_app
            .check_policy(
                executor,
                &MultiTenancyAction::new("context:ActionName", multi_tenancy.clone()),
                resource_id,
            )
            .await
    }
}

#[async_trait::async_trait]
impl InputPort for Interactor {
    async fn execute(&self, input: &InputData<'_>) -> Result<OutputData> {
        self.policy_check(&input.executor, &input.multi_tenancy, None).await?;

        // Business logic here

        Ok(OutputData { id: "...".to_string() })
    }
}
```

## Conventions

- **1 usecase, 1 public method** (`execute`)
- **Verb-first naming**: `CreateUser`, `UpdateRepo`, `DeleteData`
- **No "Usecase" suffix**: `CreateUser` not `CreateUserUsecase`
- **Always include**: `executor`, `multi_tenancy` in InputData
- **Always call**: `policy_check` at start of execute
- **Add to mod.rs**: `pub mod action_name;`

## Policy Action

Add new action to `scripts/seeds/n1-seed/008-auth-policies.yaml`:
```yaml
- table: tachyon_apps_auth.actions
  rows:
    - name: "context:ActionName"
      description: "Description"
```
