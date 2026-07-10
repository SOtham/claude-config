---
name: shipping
description: Git workflow discipline - atomic commits, worktrees for parallel work, finishing branches cleanly, PR prep, responding to review. Use when committing, opening PRs, or managing branches.
---

# Shipping

Getting work from "done on my machine" into the main branch with a history people can use.

## Commits

- **Atomic**: one intent per commit — it builds, its tests pass, and it can be reverted alone. Never mix refactoring and behavior change in one commit; the reviewer can't tell which diff lines are "safe".
- **Message**: imperative subject ≤72 chars stating *what*; body stating *why* and anything surprising. The diff already shows *how*.
- Commit at every green checkpoint while working; you can squash noise later, but you can't split a mega-commit easily.

## Worktrees for parallel streams

For a second concurrent task (urgent fix mid-feature, parallel experiments, agents working simultaneously), use `git worktree add` instead of stash juggling — each stream gets its own directory and branch with zero context-switch cost. One branch per worktree; remove worktrees when merged.

## Finishing a branch

Before merge, in order:

1. Sync with the target branch (rebase or merge per the repo's convention — read the history to see which).
2. Tidy history: squash "fix typo"/"wip" noise; keep genuinely separate steps as separate commits.
3. **Self-review the final diff hunk by hunk** as a hostile reviewer — this catches leftover debug code, stray files, and accidental reverts more reliably than any tool.
4. Run the full relevant test suite once more *after* the rebase, not just before.
5. After merge: delete the branch, remove the worktree.

Never force-push a shared branch; `--force-with-lease` only on branches that are yours alone.

## Pull request prep

- **Small PRs get reviewed; big PRs get skimmed.** Aim under ~400 changed lines; split by layer or by step if larger, each PR independently shippable.
- Description answers, in order: what changed, why, how it was verified (commands/output, screenshots for UI), and what reviewers should scrutinize. Link the issue.
- Flag known trade-offs yourself — a reviewer discovering an undisclosed hack costs trust; disclosing it costs nothing.

## Receiving review

- Respond to every comment: "fixed in <commit>", or a reasoned "keeping as-is because…". Silence reads as ignored.
- Push review fixes as new commits (or fixups) during review — force-pushing rewrites mid-review destroys the reviewer's diff context.
- A comment revealing the reviewer misread the code is a signal: the code (or a comment in it) needs to be clearer, not the reviewer smarter.
- Batch nitpicks into one pass; re-request review explicitly when done.
