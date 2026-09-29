---
name: create-scenario-test
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Create YAML scenario tests when API coverage is requested or a new endpoint, usecase, or
  GraphQL operation needs a new scenario. Use scenario-test to run existing scenarios.
---

# Create Scenario Test

Create YAML-based API scenario tests for the `muon` runner.

## File Location

```
apps/tachyon-api/tests/scenarios/{feature_name}.yaml
apps/library-api/tests/scenarios/{feature_name}.yaml
```

Keep files directly under `tests/scenarios/`; the runner does not recurse.
Use `tags` to group scenarios. The first tag is the parallel execution
group. Reserved tags: `infra` (runs in `scenario-test-infra`), `prod`
(never in CI), `compat` (API compatibility baseline, PLT-4076; put it first
on new `compat_*` files and last when adding it to an existing file).

## Template

```yaml
name: "Feature Name CRUD"
description: "Test create, read, update, delete for Feature"
tags:
  - feature

config:
  headers:
    Authorization: Bearer dummy-token
    x-operator-id: "{{vars.operator_id}}"
    Content-Type: application/json
  timeout: 30
  continue_on_failure: false

vars:
  test_name: "Test Feature"
  operator_id: "<tenant-id>"

steps:
  - id: create_feature
    name: "Create feature"
    request:
      method: POST
      url: /v1/graphql
      body:
        query: |
          mutation CreateFeature($input: CreateFeatureInput!) {
            createFeature(input: $input) {
              id
              name
              createdAt
            }
          }
        variables:
          input:
            name: "{{vars.test_name}}"
    expect:
      status: 200
      json:
        data.createFeature.name: "{{vars.test_name}}"
      not_contains:
        - '"errors"'
    save:
      feature_id: data.createFeature.id

  - id: get_feature
    name: "Get created feature"
    request:
      method: POST
      url: /v1/graphql
      body:
        query: |
          query GetFeature($id: ID!) {
            feature(id: $id) {
              id
              name
            }
          }
        variables:
          id: "{{vars.feature_id}}"
    expect:
      status: 200
      json:
        data.feature.id: "{{vars.feature_id}}"

  - id: delete_feature
    name: "Delete feature"
    request:
      method: POST
      url: /v1/graphql
      body:
        query: |
          mutation DeleteFeature($id: ID!) {
            deleteFeature(id: $id)
          }
        variables:
          id: "{{vars.feature_id}}"
    expect:
      status: 200
      json:
        data.deleteFeature: true
```

## Key Rules

- **Always add `id:`** to steps; `save:` values land in `vars`, and
  `steps.<id>.res` / `current.res` are available to CEL `test:` expressions
- **Assertions live under `expect:`** (`status`, `headers`, `json`,
  `json_lengths`, `json_eq` + `json_ignore_fields`, `contains`,
  `not_contains`, `sse`). `assertions:` / `outputs:` do not exist
- **`expect.schema` is not validated**; do not rely on it
- **Use `{{vars.xxx}}`** for reusable values, `{{timestamp}}` for uniqueness
- **Required headers**: `Authorization`, `x-operator-id` (except `/v1/me`)
- **Multi-line queries**: use `|` for GraphQL
- **SSE**: named events (`event:` lines) are matched by `expect.sse`;
  unnamed `data:` streams (OpenAI chunks) must be asserted with `contains`
  on the raw body
- **Characterization of a public contract**: add the `compat` tag and record
  it in `docs/src/tachyon-apps/testing/api-compatibility-baseline.md`

## Run Test

```bash
SCENARIO="Feature Name CRUD" mise run docker-scenario-test-single
```
