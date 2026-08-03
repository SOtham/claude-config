---
name: orchestrate
description: Subagent orchestration - when to delegate vs work inline, fan-out design, task contracts, model tier choice, agent definitions. Use when spawning subagents or parallelizing agent work.
---

# Orchestrate

Rules for delegating work to subagents: when it pays, how to specify tasks so results come back usable, and how to define reusable agents.

## When to delegate — and when not

Delegate when at least one holds:

- **Context isolation**: the task requires reading far more than the answer is worth (broad searches, log sweeps, doc digestion). The subagent burns its own context; you keep only the conclusion.
- **True fan-out**: 3+ independent, same-shaped work items (migrate N modules, review N files) that don't need each other's results.
- **Risk isolation**: experimental code changes that belong in a separate worktree until proven.

Work inline when:

- The task needs the conversation's accumulated context — a subagent starts cold and must re-derive it, which usually costs more than it saves.
- It's a single quick lookup or edit.
- Steps are sequential and each depends on the previous result.

Every spawn is paid for twice: the agent re-establishes context and re-explores, then you re-read its report. Current frontier tiers reach for subagents too readily — inline is the default, delegation is the exception you justify.

- **Don't delegate verification or review of your own work.** Verification belongs in the main loop; a verifier subagent re-derives context to re-check what you can check directly.
- **Don't delegate what you could finish in a handful of tool calls** — a few file reads, a handful of edits, a simple search. Spawn overhead exceeds the work.
- **Don't split one modest job across multiple parallel agents.** Parallel agents are for genuinely independent tracks. If one agent can do it, use one.
- **Commit to the delegation.** Once an agent reports back, don't redo its work or re-derive its findings — paying the overhead twice is the worst outcome.
- **Keep spawn counts low.** Default ceiling: 3 agents running at once; raise it only when the user asks. Measured here: heavy parallel subagents start hitting session rate limits around 3-4 concurrent.

## The task contract

A subagent knows nothing you don't tell it. Every delegation prompt needs:

1. **Goal** — one sentence, with done-when criteria.
2. **Scope** — exact paths/globs in bounds, and explicitly what is out of bounds.
3. **Context it can't discover** — decisions already made, constraints, prior findings. Don't make it re-research settled questions.
4. **Output contract** — the exact shape of the final message (fields, format, max length). The final message is *all you get back*; if you need file:line references, say so.
5. **Non-goals** — "do not refactor adjacent code", "do not commit". Scope creep is the default failure mode.

## Execution choices

- **Model tier**: mechanical or repetitive work → lightweight model; planning, debugging, judgment → highest reasoning tier available. State the tier and the reason when delegating.
- **Sync vs background**: block on results you need for the next step; run independent work in the background and continue.
- **Continue, don't respawn**: to follow up with an agent that already has context, message the existing one — a fresh spawn re-pays the entire warm-up cost.
- **Worktree isolation** for code-writing agents when parallel agents might collide or you want cheap discard.

## Fan-out discipline

- Pilot one item first; fix the prompt before launching the fleet.
- Make items truly independent — shared files mean merge conflicts.
- Hold concurrency to the ceiling above — run the remaining items in later waves — and make each item idempotent so a failed item can be re-run alone.
- Verify by sampling: spot-check a few results before trusting the batch.

## Reusable agent definitions

For a role you delegate to repeatedly, define it once (project `.claude/agents/<name>.md`) with frontmatter: `name`, `description` (when the orchestrator should pick it), `tools` (least privilege — read-only for reviewers and searchers), and optional `model` tier. The body is its system prompt: role, method, output contract. One agent = one job.
