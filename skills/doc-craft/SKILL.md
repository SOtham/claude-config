---
name: doc-craft
description: Writing documentation that gets read - READMEs, ADRs, changelogs, API docs, runbooks - with an outline approved before drafting. Use when writing or restructuring any documentation.
---

# Doc Craft

Documentation method: agree on the outline before writing prose, write for the reader's task, and keep docs where they can't rot silently.

## The universal method

1. **Reader first**: name the audience and the questions they arrive with. A doc that serves "everyone" serves no one.
2. **Outline**: headings plus one line per section stating what it will say.
3. **Approval gate**: confirm the outline with the requester *before* drafting. Rewriting an outline costs a minute; rewriting a draft costs the afternoon.
4. **Draft**: front-load answers (most docs are skimmed); every claim about behavior verified against the actual code, every command actually run.
5. **Test it**: a README quickstart is tested by following it in a clean environment; a runbook by dry-running it. Untested docs are speculation with formatting.

## Per-type rules

**README** — first screen answers: what is this, why would I use it, how do I run it in 3 commands. Depth (architecture, config reference, contributing) comes after, linked not inlined. The quickstart must actually work — it is the most-executed code in the repo.

**ADR (architecture decision record)** — one decision per record: context (forces in play), the decision, alternatives rejected *with the reason each lost*, and consequences (including the bad ones — an ADR with no downsides is advertising). Accepted ADRs are immutable history: never edit one to reflect a new decision; write a new ADR that supersedes it.

**Changelog** — written for users, not archaeologists: user-visible behavior grouped as Added / Changed / Fixed / Removed, breaking changes flagged loudly at the top with migration steps. Never a commit-log dump.

**API docs** — every endpoint/function: purpose in one line, a runnable example, and the **failure modes** (error codes, what triggers them, what the caller should do). Documenting only the happy path is documenting half the API.

**Runbook** — for someone paged at 3am: numbered imperative steps, exact commands with expected output shown, explicit decision points ("if X, go to step 7"), and a "when to escalate instead" line. Zero narrative prose.

## Comments and inline docs

Code comments state what the code cannot: invariants, units, protocol quirks, why the obvious approach was rejected. If prose is needed to explain *what* the code does, improve the code first.

## Maintenance

- Docs live as close as possible to what they describe (same repo, same directory when feasible) so diffs that change behavior can be expected to touch them.
- **Delete stale docs.** A wrong doc is worse than no doc: the reader with nothing investigates; the reader with a lie acts on it.
- When a question gets asked twice, its answer belongs in a doc; link the doc instead of re-answering.
