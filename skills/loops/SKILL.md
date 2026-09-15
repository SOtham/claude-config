---
name: loops
description: Design discipline for recurring and autonomous work - stop conditions, idempotent bodies, state files, cache-aware pacing. Use when designing or hardening a loop; to schedule one, use bundled /loop.
---

# Loops

Patterns for recurring and long-running autonomous work: polling, watch loops, scheduled jobs, and self-paced iteration. A loop without a stop condition is a bug.

## Choose the mechanism

- **Fixed interval** (e.g. every 5m): external state changes at a known cadence — CI, deploys, queues.
- **Self-paced**: cadence varies; pick each next wake based on what you just observed.
- **Scheduled/cron task**: unattended recurring work (nightly triage, weekly report) that shouldn't depend on an open session.
- **No loop at all**: if the harness or tool already notifies you when tracked background work finishes, don't poll it — schedule at most a long fallback in case it hangs.
- **Mechanics vs discipline**: in Claude Code, the bundled `/loop` and `/schedule` skills own *starting* an interval or scheduled run; this skill is the discipline (stop conditions, pacing, hygiene) applied to whatever mechanism runs.

## Every loop needs, before iteration 1

1. **Stop condition** — success state, max iterations, or time/cost budget. At least one, stated explicitly.
2. **Idempotent body** — running an iteration twice must be safe: check state before acting; no duplicate posts, comments, or commits.
3. **State file** — progress, last-seen values, and iteration count persisted outside the conversation, so a restart or context compaction doesn't reset the loop.
4. **Failure policy** — same error N times in a row (default 3) → stop and report; don't retry unchanged forever. Distinguish "condition not met yet" (keep looping) from "loop itself broken" (stop).

## Pacing (cache-aware)

Claude Code sessions run on a 1-hour prompt-cache TTL (drops to 5 min only under usage overage — don't track or preempt that, pace the same way regardless). Inside that hour there is no cache cliff to pace around: scheduling extra wakeups just to keep the cache warm is pure waste.

- Pick cadence from what you're actually waiting for, not from cache timing: an ~8-minute CI run wants one ~8-minute check, not eight 1-minute polls or a defensive short interval.
- Idle ticks with no specific signal to watch → default to long waits (20–30 min); the loop still checks back regularly.
- A wake past the 1-hour boundary forces a full-price rewrite of the whole accumulated context before the next read is cheap again — that's the cost of the gap itself, not something tighter polling fixes.

## Iteration hygiene

- Log one terse line per iteration (timestamp, observation, action, next wake) to the state file — not paragraphs to the user.
- Report to the human on *change*, not on every tick: condition met, failure policy tripped, or budget exhausted.
- Autonomous iterations stay in scope: fix-forward on the defined task only; a discovered side-issue gets logged, not chased.
- Re-verify the goal each wake — the world moves between iterations (the PR may already be merged; someone else may have fixed it). Check before acting.
