---
name: scenario-test
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Run or fix existing YAML scenario tests when API behavior verification is requested or the
  changed API surface requires scenario evidence. Do not trigger for every API edit or before
  every commit.
---

# Scenario Test

Run the YAML / Markdown scenario tests (runner: the `muon` submodule) and
fix failures.

## Commands

```bash
# Tachyon API (all scenarios, Docker)
mise run tachyon-api-scenario-test

# Library API
mise run library-api-scenario-test

# One scenario. The filter is a substring of the scenario `name:` field,
# NOT the file name.
SCENARIO="Feature flag CRUD" mise run docker-scenario-test-single

# API compatibility baseline only (PLT-4076, `compat` tag)
mise run compat-scenario-test
```

Tag selection: `TEST_SCENARIO_TAGS=a,b` keeps scenarios with any listed
tag, `TEST_SCENARIO_EXCLUDE_TAGS=infra,prod` drops them. CI runs
`scenario-test` (excluding `infra,prod`) and `scenario-test-infra`
(`infra` only). `muon/` must be checked out
(`git submodule update --init muon`).

## Test Locations

- `apps/tachyon-api/tests/scenarios/` (flat; subdirectories are ignored)
- `apps/library-api/tests/scenarios/`

## Format (muon)

```yaml
name: "Feature name"
description: "What the scenario pins"
tags:
  - feature-flag
config:
  headers:
    Authorization: Bearer dummy-token
    x-operator-id: <tenant-id>
    Content-Type: application/json
  timeout: 30
  continue_on_failure: false
vars:
  user_name: "Test User"
steps:
  - id: create_user
    name: "Create resource"
    request:
      method: POST
      url: /v1/graphql
      body:
        query: |
          mutation CreateUser($input: CreateUserInput!) {
            createUser(input: $input) { id name }
          }
        variables:
          input: { name: "{{vars.user_name}}" }
    expect:
      status: 200
      json:
        data.createUser.name: "{{vars.user_name}}"
      not_contains:
        - '"errors"'
    save:
      user_id: data.createUser.id

  - id: verify
    name: "Verify"
    request:
      method: GET
      url: /v1/auth/users/{{vars.user_id}}
    expect:
      status: 200
      headers:
        content-type: application/json
    test: current.res.body.id == vars.user_id
```

`expect` keys: `status`, `headers` (exact match, lower-case names),
`json` (dot path → value), `json_lengths`, `json_eq` +
`json_ignore_fields`, `contains`, `not_contains`, `sse`
(`has_events`, `events[].data_eq`, `event_sequence`, `ends_with`).
`schema:` is parsed but never validated. There is no regex key; use
`contains` or a CEL `test:` expression (`current.res.{status,headers,body,rawBody}`,
`steps.<id>.res`). `save:` captures JSON paths into `vars`.
`.scenario.md` files use the same keys inside ```` ```yaml scenario ```` blocks.

## Common Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| Field not found | Schema changed | Update query |
| `{{steps.xxx}}` error | Missing step id | Add `id:` to step |
| Permission denied | Missing header | Add required headers |
| Assertion failed | Wrong expectation | Update expectation or fix API |
| Scenario silently missing | File in a subdirectory or parse error | Keep files flat; CI sets `MUON_FAIL_ON_PARSE_ERROR=true` |

## Workflow

1. Run tests
2. Parse failures (step, error, expected vs actual)
3. Fix test YAML or API code
4. Re-run until pass
5. If the change touches a public contract, keep the `compat` scenarios
   green (see `docs/src/tachyon-apps/testing/api-compatibility-baseline.md`)
