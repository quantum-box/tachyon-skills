---
name: explore
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Explore codebase using Serena's semantic tools. Use proactively when: (1) User asks 'where is
  X implemented?' (2) Need to understand how something works. (3) Tracing references or data
  flow. (4) Investigating bugs.
---

# Explore

Use Serena MCP tools for efficient code exploration without reading entire files.

## Tools

### find_symbol
Find symbol by name:
```
mcp__serena__find_symbol(name_path_pattern="CreateUser", relative_path="packages/", depth=1)
```

### find_referencing_symbols
Find what uses a symbol:
```
mcp__serena__find_referencing_symbols(name_path="AuthApp/check_policy", relative_path="packages/auth/src/app.rs")
```

### search_for_pattern
Flexible regex search:
```
mcp__serena__search_for_pattern(substring_pattern="policy_check", relative_path="packages/", context_lines_after=3)
```

### get_symbols_overview
High-level file structure:
```
mcp__serena__get_symbols_overview(relative_path="packages/auth/src/usecase/create_user.rs", depth=1)
```

## Exploration Patterns

**Find implementation**: `find_symbol` → narrow with `relative_path` → `include_body: true`

**Trace usage**: `find_symbol` → `find_referencing_symbols` → read key examples

**Data flow**: handler → usecase → repository → domain (follow with `find_symbol`)

## Common Paths

- Usecases: `packages/*/src/usecase/`
- Domain: `packages/*/domain/src/`
- Handlers: `apps/*-api/src/handler/`
- GraphQL: `apps/*-api/src/handler/graphql/`
- Frontend: `apps/*/src/app/`
