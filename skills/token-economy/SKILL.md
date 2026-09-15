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

- Large file, known region → read with offset/limit, not the whole file. A 68KB source file is ~17K tokens — read it whole three times and that one file has cost 51K.
- Do not re-read files you just wrote or edited; the edit result already confirms state. Re-read only if an external tool (formatter, linter, generator) changed them. Read-then-edit-then-read on one file is the most common form of this waste — measured at 8 reads plus 8 edits of a single small note file in one session.
- Do not paste long file contents into replies; reference paths and line numbers.
- **Normalize paths to one spelling per file, and reuse it.** `C:\Dev\x`, `C:\dev\x`, and `/c/dev/x` are the same file but different strings — they defeat your own recall of "I already read this" and any dedup that depends on matching. Measured: one 17K-token controller read three times under three spellings. Pick the form the repo/tool already uses and keep it byte-identical all session.

## Delegation as context isolation

When a question requires sweeping many files but the answer is small ("where is X configured?", "which modules import Y?"), delegate to a search subagent and keep only its conclusion. The sweep happens in the subagent's context and dies with it.

Rule: delegate when (tokens to explore) is much greater than (tokens of the answer).

## Session hygiene

- Batch independent tool calls into one round instead of issuing them serially.
- Reference earlier conclusions instead of re-deriving them.
- **Run an identical command once and keep the result.** Re-issuing the same call re-pays for its whole output. Capture values that don't change within a session (auth tokens, config lookups, build IDs) into a variable or scratch file and reuse them. Measured: the same access-token fetch 10 times and the same test command 9 times in one session.
- **Do not re-poll a surface that has not changed.** Act, then observe once — not observe, observe, observe. Measured: 39 identical console reads and 21 identical page-text reads in a single browser session.
- Long outputs you may need later → write to a scratch file and read back selectively. Append or write once; rewriting the same scratch file every few turns (measured: 17 times) just re-pays for it.
- Near compaction, write a short state note (current goal, done, next step, open questions) to a file so continuation is cheap and lossless.
- If the task has outgrown the session — a second repo, a third ticket, a second day — stop and split it (CLAUDE.md, Context & Tokens). No amount of in-session trimming beats not carrying 1,500 turns of prefix.

## Prompt-cache awareness

Caches are prefix-based: a stable prefix is written once, then re-read on every later turn. Cache writes cost ≈1.25× input price for a 5-minute TTL or ≈2× for a 1-hour TTL; cache reads cost ≈0.1× input under both.

- Claude Code sessions run on a 1-hour prompt-cache TTL, not the ~5-minute default (drops to 5 min only under usage overage — don't try to track or preempt that, pace the same way regardless). A gap past the TTL forces a full-price rewrite of the _entire_ accumulated context, at roughly 2x the input rate, before reads get cheap again.
- Keep stable content (instructions, references) early in prompts; volatile content late.
- Session cost scales with turns × accumulated-context-size, not just new tokens generated: every turn re-reads the whole prior conversation from cache. A long-running session pays that read cost once per turn even if each turn is individually small — turn count is itself a cost lever. (Measured, Sept 2026 audit: the two costliest sessions of the month — 700-800 turns each, no subagent delegation — spent ~90% of their cost on cache reads and cache-rewrites, not generation.)
- A session resumed after a multi-hour or multi-day gap pays the full rewrite on the first turn back; write a handoff (`handoff` skill) and start fresh instead of leaving a session open across sittings.
- On a 1-hour TTL, pacing wakeups to beat a 5-minute window is wasted effort — the context is still cached an hour later. Match the delay to what you are actually waiting for.
- Scheduling extra turns purely to keep a cache warm is never worth it: the re-read is billed every time.

## Where the money actually goes

Measured over a real 11-day window (see the audit note below), by cost component:

| Component   | Share | What drives it                                                       | The lever                                              |
| ----------- | ----- | -------------------------------------------------------------------- | ------------------------------------------------------ |
| Cache read  | 54%   | Turn count × context size in **one long session**                    | Split the session (CLAUDE.md scope rule)               |
| Cache write | 36%   | **Cold-starting** subagents/workflows — each pays for its own prefix | Fewer, warmer agents; pass findings in (`orchestrate`) |
| Output      | 10%   | Generated text                                                       | Rarely the problem — don't optimize here first         |

Diagnose before economizing: a long solo session and a wide fan-out fail in opposite directions, and the fix for one does nothing for the other. Cache _hit rate_ is a poor signal — the measured window sat at 89–99% while still being dominated by cache-read volume.

## What NOT to economize

Correctness always outranks token savings. Never skip reading the code you are about to change, never guess file contents, and never trim a verification step to save tokens.

Nor is the always-loaded config worth trimming for cost: in the measured window, CLAUDE.md plus every skill description came to ~4,100 tokens, about **1.8% of spend**. Skill bodies load only when triggered. Session structure is where the money is — cut turns and cold starts, not doctrine.

## The context guard (enforced backstop)

`scripts/context-guard.sh` is a `PreToolUse` hook registered in this library's `settings.json` for `Read` and `Bash`. The rules above are prose a session can fail to follow; the audit showed that happening at scale, so this is the enforced layer's version of the same rule.

- **Advisory only** — it emits `additionalContext` and never a `permissionDecision`, so it warns and gets out of the way. It cannot block a call.
- **Fires on**: an unscoped `Read` of a file over ~40KB (tune with `CLAUDE_CONTEXT_GUARD_BYTES`), `git log` with no count limit, `find` with no `-maxdepth`, and `ls -R`/`--recursive`.
- **Stays silent on**: reads that already pass `offset`/`limit`, commands already piped to `head`/`tail`, and anything it cannot parse — it fails open by design, since a spurious warning on every tool call is worse than a missed one.
- **Known gap**: `cat`-ing a large file through Bash bypasses the size check, because resolving a path out of an arbitrary shell command is not reliable enough to warn on. Prefer the Read tool, which is guarded.

If a warning fires and you genuinely need the whole file, read it — the guard exists to make the cost visible, not to overrule judgment.

## Provenance

The percentages and measured counts here come from an audit of real session transcripts (`~/.claude/projects/**/*.jsonl`), parsed from the `usage` block the API returns on every assistant turn — not estimates. Re-run that audit to re-derive them for a new window; treat the shares as the shape of the problem, not constants.
