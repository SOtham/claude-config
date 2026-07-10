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

- Provider prompt caches are prefix-based with short TTLs (~5 minutes). Rapid successive turns are cheap; a pause past the TTL re-reads the whole conversation at full cost.
- Keep stable content (instructions, references) early in prompts; volatile content late.
- When pacing polls or wakeups: either stay comfortably inside the cache window (≤ ~4.5 min) or sleep long enough (20+ min) that the cache-miss cost is amortized. The worst choice is just past the TTL.

## What NOT to economize

Correctness always outranks token savings. Never skip reading the code you are about to change, never guess file contents, and never trim a verification step to save tokens.
