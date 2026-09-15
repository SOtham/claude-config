---
name: handoff
description: Compress session state for transfer - to a new session, another agent, a teammate, or after compaction. Use when context is nearly full, work pauses, or someone else continues the work.
---

# Handoff

Compress everything a successor needs into one page they can act on in five minutes. The successor may be a new session, a subagent, a teammate, or you after context compaction — write for all of them the same way.

## When to write one

- Context is filling up and the task isn't done.
- Work is pausing (end of day, blocked on external input) — a session reopened after a long gap pays a full-price cache rewrite of its entire history before it's usable again; a fresh session with a handoff is cheaper than resuming a stale one.
- Transferring the task to another agent or person.
- Before any risky long operation that might strand the session.

## Where

A file, not chat: `HANDOFF.md` in the repo (if the work is repo-bound) or the scratch directory. Chat history dies; files survive. **Update it in place** on later handoffs — one living document, not an append-only log.

## The contents, in order

1. **Goal** — one sentence, including the done-when criteria.
2. **State** — three explicit buckets, never blurred:
   - *Done and verified* (with how it was verified)
   - *Done but unverified* — the dangerous bucket; be honest about it
   - *Not started*
3. **Decisions made, each with its why** — so the successor doesn't relitigate them ("chose X over Y because Z").
4. **Open problems** — exact error text verbatim, what was already tried and ruled out. "Tests failing" is useless; the actual assertion message is gold.
5. **Next actions** — the first 1–3 concrete steps, specific enough to execute without thinking ("run X, if it passes, edit Y:120").
6. **Pointers, not payloads** — branch name, file:line references, commands to re-run, links. Never paste file contents or logs the successor can regenerate.

## Quality bar

- **The stranger test**: could a competent person with zero context resume from this file alone in five minutes? If they'd have to ask you something, that answer belongs in the file.
- One page maximum. Compression is the work — a 5-page handoff just moves the reading problem.
- No narrative history ("first I tried… then I…") except where a ruled-out path saves the successor from repeating it.
- Assumptions marked as assumptions. A handoff that states guesses as facts poisons the next session.

## Receiving a handoff

Read it fully before acting; verify the "done and verified" claims cheaply (run the tests once) before building on them; and keep the same file updated for whoever comes after you.
