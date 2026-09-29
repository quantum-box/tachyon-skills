---
name: rust-quality-checker
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Run a focused Rust quality check when the user asks, a Rust change is ready for validation, or
  PR/merge risk justifies it. Do not trigger for every Rust edit; keep local checks scoped and
  reserve workspace-wide or Docker checks for PR, merge, or high-risk work.
---

# Rust Quality Checker

Use this skill for a deliberate Rust validation point. It is not an
after-every-edit hook.

## When to Use

Use when:

- The user explicitly asks for Rust quality checks.
- A logical Rust change is complete and a focused local check is justified.
- The change is ready for PR/merge or has cross-crate, build, or deployment risk.

Do not use this skill for every `.rs` edit, as a default response to a handoff,
or when the user has asked to keep local validation minimal.

## Local Validation

1. Inspect the changed crates and choose the smallest relevant host-side check.
2. Prefer crate-scoped `cargo check`, `cargo test`, or `cargo build` through the
   repository's `mise` environment, plus `mise run fmt` only when formatting is
   part of the requested scope.
3. Do not stop containers automatically and do not start Docker checks merely
   because a Rust file changed.
4. Run `mise run ci-rust` or `mise run docker-ci-rust` only before PR/merge, for
   high-risk cross-workspace changes, or when the user explicitly requests it.

If no focused command is available, report that fact instead of silently
substituting a workspace-wide check.

## Fixing and Reporting

- Read and group failures before changing code.
- Apply only fixes caused by the requested change.
- Do not add dependencies or alter unrelated crates to make a check pass.
- Re-run the same focused check after a fix.
- Stop after repeated failures and ask for guidance.
- Report commands run, commands skipped, reasons for skips, and remaining
  failures.

## Safety Boundary

This skill may edit source files only when the user requested implementation or
explicitly requested CI/error fixes. It must not commit, push, change CI policy,
or broaden validation without the user's request.
