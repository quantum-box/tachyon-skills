---
name: find-pattern
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Find similar implementation patterns in codebase. Use proactively when: (1) Creating new
  Usecase and need reference. (2) Implementing new GraphQL resolver. (3) User asks 'how is X
  done elsewhere?' (4) Need to follow existing conventions.
---

# Find Pattern

Find existing implementations as reference for new code.

## Common Patterns to Find

### Usecase Pattern
```
mcp__serena__search_for_pattern(
  substring_pattern="impl.*InputPort",
  relative_path="packages/",
  restrict_search_to_code_files=true
)
```

### GraphQL Resolver
```
mcp__serena__find_symbol(
  name_path_pattern="QueryResolver",
  relative_path="apps/",
  depth=1
)
```

### Repository Implementation
```
mcp__serena__search_for_pattern(
  substring_pattern="impl.*Repository",
  relative_path="packages/",
  context_lines_after=5
)
```

### Policy Check Pattern
```
mcp__serena__search_for_pattern(
  substring_pattern="policy_check",
  relative_path="packages/",
  context_lines_after=3
)
```

## Pattern Categories

| Category | Search | Example Location |
|----------|--------|------------------|
| Usecase | `InputData.*executor` | `packages/auth/src/usecase/` |
| Resolver | `#[Object]` | `apps/*-api/src/handler/graphql/resolver.rs` |
| Mutation | `#[Object].*Mutation` | `apps/*-api/src/handler/graphql/mutation.rs` |
| Repository | `#[async_trait].*Repository` | `packages/*/src/interface_adapter/gateway/` |
| Domain | `def_id!` | `packages/*/domain/src/` |

## Workflow

1. Identify what pattern is needed
2. Search for similar implementations
3. Get symbol overview of found files
4. Read specific symbol bodies as reference
5. Apply pattern to new implementation
