---
name: node-quality-checker
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Run scoped TypeScript/Node quality checks when the user asks, a frontend change is ready for
  validation, or PR/high-risk work justifies it. Do not trigger for every TypeScript/React edit
  or before every commit.
---

# Node Quality Checker

Run TypeScript quality checks and auto-fix issues.

## Command

```bash
mise run ci-node
```

Runs on the host:
- TypeScript type checking
- Biome linting
- Formatting validation

## Individual Commands

```bash
# Type check specific app
pnpm exec turbo run ts --filter=tachyon

# Lint specific app
pnpm exec turbo run lint --filter=library

# Format check
pnpm exec turbo run format --filter=tachyon

# Auto-fix formatting
pnpm run format:write
```

## Common Fixes

### Type Errors
- Check generated types are up to date: `mise run docker-codegen`
- Verify imports from `@/gen/graphql`
- Check prop types match component expectations

### Lint Errors
- Biome rules: single quotes, trailing commas
- Unused imports: remove or use
- React hooks: check dependencies array

### Format Errors
```bash
pnpm run format:write
```

## Workflow

1. Prefer package-scoped host commands for the changed frontend package
2. Run `mise run ci-node` when broad Tachyon Node validation is justified
3. If codegen errors: run the applicable host codegen task first
4. Parse type/lint errors
5. Fix issues in source files
6. Run `pnpm run format:write` for formatting
7. Re-run until pass

Do not use `docker-ci-node` unless the user explicitly requests Docker
validation or the issue depends on the container environment.

## Output Format

```markdown
## Node Quality Check

**Command**: `mise run ci-node`

**Results**:
- ✅ TypeScript: No errors
- ❌ Lint: 2 errors in apps/tachyon/
- ❌ Format: 3 files need formatting

**Fixes Applied**:
- Removed unused import in page.tsx
- Added missing dependency to useEffect
- Ran pnpm run format:write

**Status**: ✅ All checks pass
```
