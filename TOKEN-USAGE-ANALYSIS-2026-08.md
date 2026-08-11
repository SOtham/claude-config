# Token Usage & Inefficiency Analysis — 1–11 Aug 2026

Prepared for handoff to another agent. Source data: local Claude Code session transcripts
(`~/.claude/projects/**/*.jsonl`) on this machine, filtered to events timestamped
`>= 2026-08-01T00:00:00Z`. All figures are **Verified** by parsing the raw `usage` blocks the
Anthropic API returns on every assistant turn (`input_tokens`, `output_tokens`,
`cache_creation_input_tokens`, `cache_read_input_tokens`) — not estimates.

Reproduction: the parser is saved at `token-usage-audit/analyze_usage.js` in this repo
(Node ≥18, no deps). Run `node analyze_usage.js > usage_report.json` after editing the `SINCE`
constant for a different window. It walks every project directory, classifies each `.jsonl` as a
main session, a directly-spawned `Agent`-tool subagent, or a `Workflow` subagent, and aggregates
tokens/tool-calls/tool-result sizes per session.

**Caveats for the next agent:**
- **Names here are pseudonyms.** Repository names (`service-alpha`, `service-beta`, `service-gamma`,
  `service-epsilon`, `AppDelta`), ticket IDs (`TICKET-nn`), module and file names, and the OS
  username were replaced before this was committed, so this library stays free of machine-specific
  identifiers. The substitution is consistent, so every count, path-spelling difference, and
  duplicate-read finding still holds — but don't go looking for these repos by name.
  Only the **numbers** are literal.
- Only **1 machine's local transcripts** are covered. If other machines or the web/mobile app were
  used in this window, their usage isn't included here.
- Cost estimates use Sonnet 5 intro pricing ($2/$10 per M in/out, cache write 1h = 2×input,
  cache read = 0.1×input) since 100% of observed calls were `claude-sonnet-5`. No Opus/Fable/Haiku
  usage was found anywhere in the window — model tier selection is not an issue here.
- "Total tokens" (855M) is dominated by `cache_read_input_tokens` — the same cached context being
  re-billed (at a 10× discount) on every turn of long sessions. It is **not** 855M tokens of fresh
  content. Treat the **cost breakdown**, not the raw token sum, as the primary signal.

---

## 1. Executive summary

- **13 sessions** (main + their subagents/workflows), **53 transcript files**, **3,656 assistant
  turns**, **~$304 estimated spend** over the 11-day window.
- **One session accounts for ~90% of all spend**: *"Run repo setup skill for ADO user story
  projects"* (`ce9a7e15…`, 4–6 Aug) — **≈$272 of ≈$304**. Everything else in the 11 days totals
  **≈$31**.
- That session is not a single small task — it snowballed from a repo-setup request into a
  multi-ticket AuthProvider/service-alpha implementation epic, running **6 `Workflow` invocations and 40
  subagent transcripts**, plus **1,513 turns in the main orchestrator loop itself**, over roughly
  two days, with only **one** auto-compaction the whole time.
- Root driver of cost is **turn-count × context-size**, not any single oversized tool call or
  wrong model choice. Cache hit rates are actually good everywhere (89–99%); the problem is how
  large the cached context grew and how many times it was re-sent.
- Secondary, smaller findings: a handful of duplicate large file reads, some worktree/branching
  rework, and a burst of short fragmented sessions on one day. Detail below.

---

## 2. Cost breakdown

### 2.1 By cost component (grand total, all sessions)

| Component | Tokens | Unit price (Sonnet 5 intro) | Cost |
|---|---:|---:|---:|
| Cache read | 825,386,086 | $0.20/M | $165.08 |
| Cache write (1h) | 27,145,503 | $4.00/M | $108.58 |
| Output | 2,978,702 | $10.00/M | $29.79 |
| Fresh input | 65,160 | $2.00/M | $0.13 |
| **Total** | **855,575,451** | | **$303.58** |

Reading this: **cache read is the single biggest line item at 54% of spend**, purely on volume —
every turn of a long session re-bills its entire cached prefix at the discounted rate, and one
session had 2,893 turns between its main loop and subagents. **Cache write is 36% of spend** and
is the direct cost of cold-starting subagents/workflows — every one of the 40 subagent transcripts
pays a fresh cache-write for its own system prompt + initial context. Output tokens are a minor
10%.

### 2.2 By day

| Date | Assistant turns | Tokens | Est. cost |
|---|---:|---:|---:|
| 2026-08-04 | 846 | 93.4M | $31.49 |
| 2026-08-05 | 1,632 | 248.3M | $142.81 |
| 2026-08-06 | 1,149 | 511.7M | $127.44 |
| 2026-08-11 | 29 | 2.1M | $1.83 |

No activity found 1–3 Aug or 7–10 Aug. The 5th and 6th alone are 89% of the window's spend, both
driven by the one dominant session (see §3).

### 2.3 By project / working directory

| Project (cwd) | Assistant turns | Tokens | Est. cost |
|---|---:|---:|---:|
| `C--Users-USER` (home dir — cross-repo orchestration work) | 3,005 | 777.7M | $275.99 |
| `AppDelta` | 504 | 63.7M | $18.94 |
| `C--Dev-Repos` (container root — AuthProvider MCP setup, this analysis) | 117 | 12.0M | $7.56 |
| `service-alpha` | 30 | 2.1M | $1.08 |

---

## 3. Deep dive: the dominant session (`ce9a7e15-050a-4b94-bec8-677b86359842`)

- **Title:** "Run repo setup skill for ADO user story projects"
- **cwd:** `C:\Users\USER` (not inside a specific repo — it dispatched work into repos via
  worktrees/subagents)
- **Span:** 2026-08-04 11:34 → 2026-08-06 12:59 (≈2 days elapsed, not continuous)
- **Main-loop turns:** 1,513 (cost ≈$207 on its own: cacheRead 655.4M, cacheCreate 18.7M, output
  1.9M tokens)
- **Delegated (subagent) turns:** 1,380 across 40 agent transcripts in 6 `Workflow` runs plus a
  handful of direct `Agent`-tool calls (cost ≈$65)
- **Auto-compactions:** 1, for the entire 2-day, ~2,900-turn lifetime.

### 3.1 What actually happened (from the transcript)

The task started as a single repo-setup request against an ADO user story, then organically grew
into a full implementation epic:

1. `Lets run the repo setup skill for the relevant projects associated with this ADO user story…`
2. Repo-setup skill dispatched, background task-notifications start arriving.
3. `Have a look at the plan, and spec documents in service-alpha, as well as the tickets on the ADO
   board, and let's begin with the implementation, once a AD[O]…`
4. `While the council is running in the background spin up a new agent with the needed skills to
   continue with the next ticket, continue to orchestrate…` — deliberate multi-agent fan-out
   strategy (this is why 6 Workflows / 40 agents exist — largely **by design**, not accidental).
5. Ticket-by-ticket implementation work followed (AuthProvider rule-to-action migration, tickets referred
   to as TICKET-07/TICKET-08), including test-coverage cleanup and a full "bring changes from the
   worktrees back to the original repos" consolidation pass.
6. Visible friction/rework: *"The branching is broken I cannot push the branches to origin because
   you created them wrong"*, *"The remote tracking references are wrong"*, plus at least one
   dropped turn (*"Your previous response had no visible output. Please continue…"*) and one
   explicit context-exhaustion restart (*"This session is being continued from a previous
   conversation that ran out of context…"*).

### 3.2 Where the tokens went

**Main loop tool calls:** 769 Bash, 327 Read, 167 Grep, 157 Edit, 45 Write, 31 TodoWrite, 22 Glob,
22 StructuredOutput, plus browser-automation MCP calls (`mcp__Claude_Browser__*`, ~50+ calls,
consistent with driving Azure DevOps in a browser).

**Per-subagent cost distribution** (from the 40 agent transcripts): the 15 largest agents each
independently ran 50–90 turns over 10–25 minutes and each accumulated 1–8 **million** cache-read
tokens on their own — i.e. these weren't quick single-shot delegations, they were long exploratory
sub-sessions in their own right. A handful of agents at the other extreme (2 turns, 0 cache-read)
were legitimate single-shot synthesis/handoff steps and are not a concern.

**Concrete duplicate-work evidence** (repeated identical tool calls within the session):
| Tool + target | Count |
|---|---:|
| `Read` — `service-beta.impl-TICKET-06\...\AuthClient.cs` | 9× |
| `Read` — `service-alpha.feat-TICKET-02\...\tenant.yaml` | 9× |
| `Bash` — `dotnet test .../ModuleA.Test.csproj` | 9× |
| `Read` — `service-alpha.feat-TICKET-02\closure-note.md` | 8× |
| `Edit` — same `closure-note.md` | 8× |
| `Edit` — `service-alpha.feat-TICKET-02\...\Sample Action\code.js` | 7× |

The single largest tool result was a ~68KB / ~17K-token C# controller
(`LargeController.cs`), and it was read **three separate times** — once via a
`C:\dev\Repos\...` path and twice more via a `/c/dev/Repos/...` (POSIX-style, same drive,
different casing) path — i.e. different agents/tools re-fetched the identical file instead of the
finding being reused. This is a good pattern to point a fix at: subagents in this workflow don't
appear to share discovered file contents with each other, so overlapping investigation gets paid
for multiple times.

### 3.3 Why this session got so expensive — root cause

Not a wrong model, not one giant tool call, not poor cache hit rate (96.8% — genuinely good).
The cost is **structural**: a single continuous main-loop session was used as the orchestrator for
what turned out to be a multi-day, multi-repo, multi-ticket epic (AuthProvider migration + service-alpha +
service-beta work, across at least 3 separate git worktrees), instead of being split into fresh
sessions per ticket/repo or delegated more completely to isolated subagents. The main loop's
context grew continuously for ~1,500 turns and was compacted only once, so by the later stages
each turn was re-billing several hundred thousand cached tokens just to keep going. Layered on top,
the 6 `Workflow` runs paid full cold-start cache-write costs per agent (40× over two days) and — per
§3.2 — some of those agents duplicated each other's file discovery.

---

## 4. Everything else (the other ~$31)

All other sessions are individually cheap and healthy (92–99% cache hit rates, $0.6–$5 each):

| Session | Project | Title | Turns | Cost |
|---|---|---|---:|---:|
| `c5245a13` | AppDelta | (untitled) | 355 | $12.76 |
| `3e266ea6` | AppDelta | Continue from handoff doc | 103 | $4.18 |
| `22bc9a0b` | C--Dev-Repos | Set up AuthProvider MCP for dev/staging tenants | 78 | $4.96 |
| `c414f253` | home dir | Address PR comments on service-epsilon | 74 | $2.53 |
| `dd69e090` | home dir | Address PR comments on service-alpha | 38 | $1.35 |
| `1efec583` | service-alpha | Match VS Code theme to ayu terminal scheme | 30 | $1.08 |
| `4d9324a9` | C--Dev-Repos | *(this analysis session)* | 29 | $1.83 |
| `096635d2` | AppDelta | Update theme to ayu color scheme | 28 | $1.37 |
| `51fdef9c` | AppDelta | (untitled, 1 min) | 18 | $0.63 |
| `5def9dda` | C--Dev-Repos | Initialize AuthProvider MCP server | 10 | $0.76 |
| `bfe144f9` | AppDelta | Add X-Frame-Options header | 0 recorded* | $0.00 |
| `2a913157` | C--Dev-Repos | (untitled, no assistant turns) | 0 | $0.00 |

\* No assistant-turn usage recorded in-window for this file; likely a session that was opened but
whose actual work happened in another file, or occurred entirely before the window.

**Observation, not a strong finding:** on 4 Aug, AppDelta alone has 5 distinct session starts
within about 3 hours (`096635d2` → `3e266ea6` → `51fdef9c` → `bfe144f9` → `c5245a13`), and one of
them explicitly says "Continue from handoff doc." This matches the deliberate handoff-before-
compaction workflow already documented in this user's global CLAUDE.md — each restart is a
reasonable trade (a few hundred K cache-write tokens, a few hundred dollars-worth... actually
cents, not dollars, at this scale) to buy a clean context. Flagging it only so the next agent
doesn't mistake it for accidental fragmentation; it looks intentional.

---

## 5. Findings ranked by impact

1. **(High)** One long-lived, multi-day orchestrator session was used for what became a
   multi-repo, multi-ticket epic. This single choice is responsible for ~90% of 11 days of spend.
   → *Investigate:* should genuinely multi-day/multi-ticket work be split into one session per
   ticket (or per repo), with the cross-cutting orchestration itself delegated to a `Workflow`
   rather than living in the interactive main loop? The user's own CLAUDE.md already has a
   `handoff` skill and a `token-economy` skill for exactly this situation — worth checking whether
   they were actually invoked mid-session (only one compaction fired in ~2,900 turns, which
   suggests they weren't used proactively here).
2. **(Medium)** Subagents inside the same `Workflow` runs re-discovered the same files
   independently (9× repeated reads of the same config/source files, a 17K-token controller file
   read 3 times). → *Investigate:* whether the workflow scripts pass discovered context between
   pipeline stages, or whether every stage re-explores from scratch.
3. **(Medium)** Visible git-worktree branching mistakes (wrong branches created, broken remote
   tracking refs) caused user-visible rework mid-session — a cost in turns/tokens, not something
   this token analysis can size precisely, but the transcript quotes are direct evidence. →
   *Investigate:* the worktree-creation step in whatever skill/workflow drives multi-repo work
   (likely `Workflow`'s `isolation: "worktree"` or a custom script) for the specific branch/remote
   bug.
4. **(Low)** ~40 subagents each cold-starting (full cache-write) is an inherent cost of the
   fan-out strategy the user explicitly requested ("spin up a new agent... continue to orchestrate
   in parallel"). Not obviously wrong, but worth knowing it's ~$108 of the $304 all by itself
   (cache-write across the whole window) — a concentration/parallelism-vs-cost trade-off, not a
   bug.
5. **(Informational)** Model selection is already optimal: 100% Sonnet 5 across every session and
   subagent in the window — no Opus/Fable usage to right-size.

---

## Appendix: reproduction artifacts

- `C:\Dev\Repos\token-usage-audit\analyze_usage.js` — the aggregation script (Node, stdlib only).
- `C:\Dev\Repos\token-usage-audit\usage_report.json` — full structured output for this window
  (per-session tokens, top tool calls, top tool-result byte counts, duplicate-call lists, large
  individual tool results, cache/cost math) — richer than what's summarized above; read this
  directly for anything not covered in this doc.
- Session IDs referenced above are the `.jsonl` basenames under
  `~/.claude/projects/<project-dir>/`; subagent/workflow transcripts for the dominant session live
  under `~/.claude/projects/C--Users-USER/ce9a7e15-050a-4b94-bec8-677b86359842/subagents/`.
