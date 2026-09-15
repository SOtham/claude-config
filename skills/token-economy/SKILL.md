---
name: token-economy
description: Context and token discipline - scoped search escalation, surgical file reads, subagent isolation, cache-aware pacing. Use for broad exploration, long sessions, or when context is filling up.
---

# Token Economy

Context is a budget. Spend it on reasoning, not on raw text you didn't need. These rules keep sessions fast, cheap, and coherent.

## Searching: escalate, never start broad

1. Known file → read just that file (targeted range if large).
2. Neighbors → the caller/callee/sibling you actually need.
3. Targeted search → grep with a constrained path and pattern; cap results (head-limit style) so one bad pattern can't flood context.
4. Repo-wide search → last resort, still pattern-constrained.

Never run unscoped commands that can return unbounded output (recursive listings, `git log` without `-n`, full verbose test logs). Add limits first.

## Reading files

- Large file, known region → read with offset/limit, not the whole file.
- Do not re-read files you just wrote or edited; the edit result already confirms state. Re-read only if an external tool (formatter, linter, generator) changed them.
- Do not paste long file contents into replies; reference paths and line numbers.

## Delegation as context isolation

When a question requires sweeping many files but the answer is small ("where is X configured?", "which modules import Y?"), delegate to a search subagent and keep only its conclusion. The sweep happens in the subagent's context and dies with it.

Rule: delegate when (tokens to explore) is much greater than (tokens of the answer).

## Session hygiene

- Batch independent tool calls into one round instead of issuing them serially.
- Reference earlier conclusions instead of re-deriving them.
- Long outputs you may need later → write to a scratch file and read back selectively.
- Near compaction, write a short state note (current goal, done, next step, open questions) to a file so continuation is cheap and lossless.

## Prompt-cache awareness

- Claude Code sessions run on a 1-hour prompt-cache TTL, not the ~5-minute default (drops to 5 min only under usage overage — don't try to track or preempt that, pace the same way regardless). A gap past the TTL forces a full-price rewrite of the *entire* accumulated context, at roughly 2x the input rate, before reads get cheap again.
- Keep stable content (instructions, references) early in prompts; volatile content late.
- Session cost scales with turns × accumulated-context-size, not just new tokens generated: every turn re-reads the whole prior conversation from cache. A long-running session pays that read cost once per turn even if each turn is individually small — turn count is itself a cost lever. (Measured, Sept 2026 audit: the two costliest sessions of the month — 700-800 turns each, no subagent delegation — spent ~90% of their cost on cache reads and cache-rewrites, not generation.)
- A session resumed after a multi-hour or multi-day gap pays the full rewrite on the first turn back; write a handoff (`handoff` skill) and start fresh instead of leaving a session open across sittings.

## What NOT to economize

Correctness always outranks token savings. Never skip reading the code you are about to change, never guess file contents, and never trim a verification step to save tokens.
