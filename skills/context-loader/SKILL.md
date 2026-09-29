---
name: context-loader
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Load focused domain context when a task is unfamiliar, high-risk, or the user asks for it. Do
  not trigger merely because a feature or domain name is mentioned.
---

# Context Loader

Load relevant context for focused work on specific domains.

## Domains

### Auth
```
Paths: packages/auth/, apps/*/src/handler/graphql/*auth*
Memories: development_guidelines
Key files: packages/auth/src/app.rs, packages/auth/domain/src/
```

### Payment / Billing
```
Paths: packages/payment/, packages/catalog/
Memories: project_overview (NanoDollar section)
Key files: packages/payment/src/app.rs, docs/src/architecture/nanodollar-system.md
```

### Library
```
Paths: apps/library-api/, apps/library/, packages/library/
Key files: apps/library-api/src/usecase/, apps/library-api/schema.graphql
```

### LLMs / AI
```
Paths: platform/aip/gateway/, platform/aip/runtime/agent/, providers/
Key files: platform/aip/gateway/src/app.rs, apps/tachyon-api/src/handler/agent/
```

### CRM
```
Paths: packages/crm/, packages/hubspot/
Key files: packages/crm/src/app.rs
```

### Frontend (Tachyon)
```
Paths: apps/tachyon/src/
Key files: apps/tachyon/src/app/, apps/tachyon/src/gen/graphql.ts
```

## Workflow

1. Identify domain from user request
2. Read relevant Serena memories
3. Get symbols overview of key files
4. Load related taskdocs in `in-progress`, `todo`, `backlog`, and recent
   `completed` entries for that domain
5. Load linked DDs and ADRs when taskdocs reference them
6. Present context summary

## Context Summary Format

```markdown
## Context: [Domain]

**Key Files**:
- path/to/main.rs - Main entry point
- path/to/usecase/ - Business logic

**Patterns Used**:
- Clean Architecture with InputData/InputPort
- Policy-based authorization

**Related Taskdocs**:
- docs/src/tasks/in-progress/xxx/

**Related Design Docs / ADRs**:
- docs/src/tasks/in-progress/xxx/design.md
- docs/src/architecture/decisions/ADR-xxxx-xxx.md

**Ready to implement in this domain**
```
