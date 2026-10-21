---
name: stack-pr
description: >-
  Applies only to quantum-box/tachyon-apps. Plan dependent PR layers before
  implementation, publish Ready stacked PRs, and maintain their bases after
  lower-layer edits or merges. Use for multi-part dependent work or an existing stack.
---

# Stack PR

## Placement before editing

- Inspect the current branch, worktrees, open PR bases, and Linear dependencies.
  A `blocked by` issue or implementation dependency on an open PR belongs above
  that PR. Independent work belongs in a separate branch or stack.
- Choose one reviewable concern per layer before implementation. Create child
  branches from the preceding PR head, with that branch as the PR base. If the
  prerequisite already merged, start from updated `main`.
- For an existing stack, edit the layer that owns the concern. Do not put a
  lower-layer fix in the top branch. Preserve other worktrees and local edits.
- Record the parent PR, branch, taskdoc, and intended merge order in the taskdoc.

## Tool choice

Use the `gh-stack` skill when available for command details and recovery.
This skill remains usable without that separately installed skill. Check
`gh stack <command> --help` for installed-version flags. Do not install tools,
change auth scopes, or publish just to inspect or plan a stack.

When gh-stack and repository support are available:

- Read state with `gh stack view --json`; bare `view` opens a TUI. Exit 2 means
  not in a stack, not permission to initialize or discard an existing stack.
- Create explicit named layers with `gh stack init codex/<bottom>` and
  `gh stack add codex/<child>`. Do not use interactive `modify` or `switch`.
- For authorized publication, use `gh stack submit --auto --open`; omitting
  `--open` creates drafts, which conflicts with Tachyon's Ready PR convention.
- After lower-layer commits, run `gh stack rebase --upstack`, then verify
  affected layers before publishing. Use an explicit `--remote` for commands
  supporting it when multiple remotes lack a configured push default.
- Navigation can locate another worktree with `--print-path`; never steal an
  occupied branch. Rebase/sync may change other clean worktrees: inspect owners
  first, and leave unrelated or active worktrees alone.

If gh-stack is unavailable or stacked PR support is disabled, preserve the
same branch/base chain with ordinary Git and the GitHub connector. Verify
head/base and each layer's diff explicitly. Never silently flatten the chain
or widen credentials to make a preferred tool work.

## Ready checks per layer

- Apply `task-pr-ready` independently to each layer. Check the diff against its
  actual parent branch; inherited changes are not this layer's implementation.
- Read the component version on both `origin/main` and the immediate parent.
  Each implementation layer must introduce its own version increase over the
  inherited version, and still exceed `origin/main`. Archive its taskdoc under
  that layer's introduced version; do not reuse the parent's bump as its own.
- Keep PR title, scope, verification, and dependency links specific to the layer.
  Verify all PRs are Ready and point to their intended bases.
- Creating or extending a stack does not authorize publishing or merging it.
  Respect the user's requested scope and existing auth constraints.

## Lower-layer changes and merges

- Rebase dependent layers after a parent changes, including squash merges.
  Verify parent changes are not repeated in child diffs. Recheck versions and
  taskdoc archive paths if the parent bump changed.
- `gh stack sync` can fetch, rebase, and push; use it only within authorized
  scope, and verify the resulting state. It can report `Sync aborted` with
  exit 0. Do not prune branches or remove worktrees by default.
- Merge only with user authorization, bottom-up. With supported gh-stack use
  `gh stack merge <target> --yes` after inspecting the exact target set: the
  target may include all unmerged ancestors, or an entire stack. Authorization
  for one PR does not automatically authorize its ancestors.
- After merges, inspect actual GitHub head/base state before retargeting or
  continuing. Use the tool's recorded owner for conflict recovery.
- Check CI once. If pending and no independent work remains, reuse or create
  a scheduled follow-up as instructed by the repository; do not wait in a loop.

## Output

Report layer order, each branch and PR base, verification per changed layer,
publication/merge status, and remaining dependencies.
