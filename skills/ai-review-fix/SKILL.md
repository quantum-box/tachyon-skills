---
name: ai-review-fix
description: |
  Applies only to work in the quantum-box/tachyon-apps repository.
  Analyze AI review comments (Codex, Devin, Codex, etc.) on the current PR and create a prioritized fix plan.
  Use this skill when:
  (1) User asks to fix AI review issues ("AIレビュー対応", "レビュー修正", "PR review fix")
  (2) User runs /ai-review-fix command
  (3) User mentions addressing review feedback from automated reviewers
---

# AI Review Fix

Analyze AI review comments on the current PR and create a prioritized fix plan.

## Workflow

### 1. Fetch PR and AI Reviews

```bash
gh pr view --json number,title,url,comments,reviews
```

Extract comments from AI reviewers:
- `Codex` - Codex AI reviewer
- `devin-ai-integration` - Devin AI reviewer
- `chatgpt-codex-connector` - Codex reviewer

### 2. Parse and Categorize Issues

From review comments, extract and categorize:

**Priority 1 (Critical - Must Fix)**
- Security vulnerabilities (SQL injection, XSS, etc.)
- Data loss risks
- Transaction safety issues
- Missing validation that could cause crashes

**Priority 2 (Important)**
- Logic errors
- Missing error handling
- Test coverage gaps
- Performance issues

**Priority 3 (Nice to Have)**
- Documentation improvements
- Code style suggestions
- Refactoring suggestions

### 3. Create Fix Plan

For each issue, identify:
- File path and line numbers
- Current problematic code
- Recommended fix
- Test to verify fix

### 4. Execute Fixes

For each Priority 1 issue:
1. Read the relevant file
2. Apply the fix
3. Run compile check (`mise run check`)
4. Add/update tests if needed
5. Run tests for affected code

### 5. Verify All Fixes

After all fixes:
```bash
mise run check
```

## Output Format

Present findings as:

```markdown
## AI Review Analysis for PR #XXX

### Priority 1 (Must Fix)
1. **[Issue Title]** (`file:line`)
   - Problem: ...
   - Fix: ...

### Priority 2 (Important)
...

### Priority 3 (Nice to Have)
...

## Fix Plan
1. [ ] Fix issue X in file Y
2. [ ] Add test for Z
...
```

## Notes

- Always run compile check after each fix
- Add tests for any security-related fixes
- Update existing tests if behavior changes
