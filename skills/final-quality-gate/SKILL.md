---
name: final-quality-gate
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Run scoped final checks before PR/merge or when the user explicitly requests final validation.
  Select checks for changed packages or crates; do not trigger for every handoff and do not run
  Docker by default.
---

# Final Quality Gate

Use this skill for final validation, not for incremental development. The gate
must be proportional to the changed surface and the risk of the change.

## When to Use

- The user explicitly requests final validation.
- Work is ready for PR or merge.
- A high-risk change needs broader validation.

Do not trigger only because a taskdoc phase or implementation is complete. Do
not run Docker or workspace-wide checks merely to create a clean handoff.

## Workflow

1. Inspect the diff and identify the changed packages, crates, and workflows.
2. Select the narrowest complete host-side checks.
   - Rust: prefer crate-scoped `cargo check`, `cargo test`, or `cargo build`;
     use `mise run fmt` when formatting is in scope.
   - Node: use package-scoped `format`, `lint`, `ts`, `test`, or `build` tasks.
   - UI/user-flow changes: use `browser-test` or `playwright-cli` as applicable.
3. Use `mise run ci-rust`, `mise run ci-node`, or `mise run ci` only when the
   changed surface or PR stage justifies broad validation.
4. Use `mise run docker-ci*` only for explicit Docker validation, container,
   Compose, image, or startup changes, or a Docker-specific failure.
5. If a check fails, fix only failures caused by the requested change. Do not
   disable tests, lint rules, or unrelated checks.
6. Re-run the same selected checks after a fix. Stop after repeated failures and
   ask for guidance.

## Completion Report

Report:

- checks run and their results;
- checks skipped and the reason for each skip;
- remaining failures or risks;
- whether the result is ready for PR/merge or only locally validated.

This skill does not commit, push, or change CI policy unless the user explicitly
requests those actions.
