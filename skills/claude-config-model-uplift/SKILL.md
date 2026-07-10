---
name: claude-config-model-uplift
description: Run cheaper-tier sessions at top-tier standard - config preflight, session scaffold, failure-mode countermeasures, escalation, measured promotion. Use when a lightweight model must do real work.
---

# Claude-Config Model Uplift

The campaign for this library's stated purpose (owner, 2026-07-07): make cheaper-tier sessions (e.g. today's Sonnet-class and below — dated examples of the lightweight tier) work at the standard the highest reasoning tier sets. It is decision-gated: each phase ends with an observable gate — proceed, branch, or escalate. Honesty rule: **statuses are per-item and each cites its experiment-log entry** (`claude-config-research/references/experiment-log.md`); anything without a cited entry is **candidate**, and every expected observation without a measured number stays qualitative ("you should see X; if Y → branch") — never an invented percentage.

## Phase 0 — Preflight: prove the config is present

The library cannot uplift a session it never reached, and an absent config fully explains "the model ignored the rules". Checking this last is the campaign's #1 wrong path.

1. **Structural health** — both scripts are read-only (interpretation: `claude-config-diagnostics`):

   ```powershell
   powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\claude-config-diagnostics\scripts\doctor.ps1"
   powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\claude-config-diagnostics\scripts\lint-skills.ps1"
   ```

2. **Surface check** — local Claude Code reads skills automatically through the `~/.claude/skills` junction (a Windows directory link into this repo); **web sessions get none of user-level `~/.claude`** — skills reach them only via the claude.ai zip upload or the repo's own `.claude/skills/` (finding: `claude-config-platform-reference` §6; routes: `claude-config-distribution`). For the web surface, also check for stale zips with `scripts\check-dist.ps1` in `claude-config-diagnostics`.
3. **Repo check** — the target repo has its own `CLAUDE.md`, or at least the `CLAUDE-SNIPPET.md` rules pasted into it (procedure: `repo-setup`). Locally, the `settings.json` SessionStart hook flags a missing CLAUDE.md; web sessions have no such hook.

**Gate:** all three pass → Phase 1. Any fail → fix the config first (`repo-setup` / `claude-config-distribution` / broken-but-present config: `claude-config-debugging`). Do not judge, tune, or blame the model before this gate passes.

## Phase 1 — Session protocol: the uplift scaffold

Open every lightweight-tier working session with this scaffold (status: **trialed, supported at n=3 per arm** — experiment-log entries #7 and #9, 2026-07-10: scaffolded Sonnet-class arms went 9/9 on the pre-declared observables across three tasks, loading the correct skill as their *first* action every time; bare arms never loaded a skill — 0/6 cumulative across entries #6–#9 — though they passed the other observables). It invents no doctrine — each point routes to a section of the global `CLAUDE.md`; quoted phrases are verbatim from it, so the session is held to rules it already carries:

```text
This session runs on a lightweight tier. Hold yourself to CLAUDE.md, strictly:
1. Skill Routing — before starting work, pick the matching skill from the
   "Skill Routing" table and load it: "Load the matching skill *before*
   starting the work, not after getting stuck." Tell me which skill you loaded.
2. Planning Gate — architecture, migration, API, security, or any change
   touching 3+ files: plan first under "## Proposed Architecture &
   Implementation Plan" and wait for my explicit "y". "Silence is not
   confirmation."
3. Verification — end by summarizing "exactly what was verified and what was
   not". "MUST NOT claim success without verification"; show command output.
The task (one skill's worth of work): <task>
```

Web session (no user-level CLAUDE.md, so no routing table): replace point 1 with an explicit skill invocation — name the needed skill in the task prompt, e.g. "load `/writing-code` first" (this is lever 3 in the Ranked solution menu below).

Keep tasks small and single-skill-shaped — one task ≈ one Skill Routing row; a new job gets a new session. Rationale, not measurement: instructions compete with a growing context, and cheaper tiers are assumed to degrade faster in long mixed-context sessions (Assumption — the harness in `claude-config-research` is what will test it). Mid-session context discipline: `token-economy`; splitting oversized work: `handoff`.

**Gate:** early in the session it names the skill it loaded; a qualifying change pauses at a plan and waits; the close contains a verified/not-verified split. If instead it dives straight into edits or closes with a bare "done" → apply the matching Phase 2 countermeasure. Same class fails twice in one session → Phase 3.

## Phase 2 — Failure-mode table

**Predicted failure classes — status candidate** until the eval harness measures them (`claude-config-research`) — except "Skills never load", which is now **measured**: **0/9** unscaffolded skill loads across every scriptable surface (entries #6–#10; authoritative itemized tally: entry #10's correction line) — treat lever 2 (scaffold, itself trialed n=3) or lever 3 (explicit invocation) as required for cheap-tier sessions, not optional. Recognize each in the transcript, never from the session's self-description; ground truth for "did a skill load" is the transcript grep in `claude-config-validation` §2.

| Failure class | Recognize in transcript | Immediate countermeasure | Re-anchor with |
| --- | --- | --- | --- |
| Edits before orienting | First tool call is an edit/write; no read of the target file or a neighbor | Stop; require conventions/orientation findings before any diff | `writing-code` Phase 1 |
| Unverified success claim | "Done/should work" with no command output, no verified/not split | Reject the claim; demand the Verification summary with outputs | `writing-code` Phase 3; CLAUDE.md "Verification" |
| Skills never load | No Skill invocation recorded; generic, method-free behavior | Put the invocation in the task prompt: "load /writing-code first" (lever 3) | CLAUDE.md "Skill Routing" table |
| Context flooding | Unscoped grep, recursive listing, or full logs dumped into context | Interrupt; re-run scoped with limits; restate the search-escalation ladder | `token-economy` |
| Speculative fix | Patch appears with no reproduction and no root-cause statement | Require the root cause "in one sentence" before any fix | `root-cause`; CLAUDE.md "Debugging" |
| Plan-gate skip | Multi-file (3+) diff starts with no plan and no wait for "y" | Halt; demand the plan header and explicit confirmation | `architect`; CLAUDE.md "Planning Gate" |

## Phase 3 — Escalation policy

- **Never hand to the lightweight tier** what CLAUDE.md "Delegation" reserves for the top: "planning, debugging, architecture, and complex implementation" stay on the highest reasoning tier available; the lightweight tier gets "repetitive, low-risk work". Security-sensitive work rides the Planning Gate → top tier too.
- **The split pattern**: the strong model plans and reviews; the cheap model executes mechanical, well-contracted steps. Write each delegation as a full task contract — goal, scope, context, output contract, non-goals — per `orchestrate` (status: candidate for uplift; highest setup cost on the menu).
- **Stop rule** (CLAUDE.md "Terminal Operations"): after **3** failed attempts, stop, produce a concise log summary, and escalate — to the higher tier or the owner. Also escalate when a Phase 2 class recurs after its countermeasure: the task was mis-tiered, not mis-prompted.

## Phase 4 — Measure and promote

Campaign success is measured, never judged by eye:

- **Today (manual, qualitative):** trigger tests and adherence spot-checks against pre-declared observables — protocols and pass/fail standards in `claude-config-validation` (its weighting: 1 case = anecdote, 3+ consistent = evidence).
- **Next (quantitative):** the measured-adherence harness over headless runs — program owned by `claude-config-research`.
- **Promotion:** a scaffold line or countermeasure that proves out is promoted into the library — skill edit, CLAUDE.md line, or hook, placed by the layer rule in `claude-config-architecture` §2 — and shipped through `claude-config-change-control`.

**Gate:** promotion requires attached before/after evidence. Without it, the item stays in this skill, labeled candidate.

## Ranked solution menu

Work top-down; stop at the cheapest lever that closes the gap.

| # | Lever | Cost | Status |
| --- | --- | --- | --- |
| 1 | Config-only: presence verified (Phase 0), routing table already in CLAUDE.md | Minutes — already built; just verify | Structure verified 2026-07-08; uplift effect candidate |
| 2 | Session scaffold — the Phase 1 paste | One paste per session | **trialed, supported n=3** (entries #7, #9) — the strongest measured lever |
| 3 | Explicit skill invocation in the task prompt (e.g. "/root-cause") | Near zero per task | candidate |
| 4 | Orchestrated split: strong plans/reviews, cheap executes (Phase 3) | Highest setup: task contracts + review loop (`orchestrate`) | candidate |
| 5 | Hook-based enforcement, e.g. a hook injecting scaffold reminders as context | `settings.json` change — the highest change gate (`claude-config-change-control`) | **retired as designed** (entry #8, 2026-07-10): a `UserPromptSubmit` reminder hook fired in headless but changed nothing (2/3 = baseline), and does NOT fire for subagent task prompts at all. A `SessionStart`-scoped variant remains untested. Do not rebuild without a new pre-registered experiment |

## Fenced wrong paths

- **Blaming the model before Phase 0 passes** — an absent config explains every "adherence failure" by itself.
- **Stuffing procedures into CLAUDE.md** to force adherence — busts the ~120-line budget; its own maintainer comment: "long files reduce adherence" (doctrine: `claude-config-architecture`).
- **Hardcoding model names** in config or scaffolds — CLAUDE.md "Future Compatibility" requires capability-tier language; dated names only as examples.
- **Trusting the session's self-report** ("I followed writing-code") — grade the transcript against the Phase 2 observables; self-report is explicitly non-evidence (`claude-config-validation` §7; CLAUDE.md "Verification").

## When NOT to use this skill

- Designing the evidence itself — trigger tests, spot-check protocol, pass/fail standards → `claude-config-validation`
- Building the measured-adherence harness, its discipline and milestones → `claude-config-research`
- Generic subagent delegation not about tier uplift → `orchestrate`
- Config present but not taking effect → `claude-config-debugging`

## Provenance and maintenance

Written 2026-07-08 (zero measured adherence data existed then). 2026-07-10: field data landed — entries #6–#10 in `claude-config-research/references/experiment-log.md` (unscaffolded loads 0/9 itemized in entry #10's correction; scaffold A/Bs 9/9 vs 6/9 at n=3/arm; hook lever retired); statuses above updated to match. Everything uncited stays candidate until the program produces more numbers. Re-verify before trusting:

- The six CLAUDE.md sections quoted here still exist (PowerShell, tested): `Select-String -Path "$HOME\.claude\CLAUDE.md" -Pattern '^## (Skill Routing|Planning Gate|Verification|Delegation|Terminal Operations|Future Compatibility)'` — expect 6 hits; re-check quoted phrases after any CLAUDE.md edit
- Diagnostics scripts present and runnable (tested 2026-07-08: doctor HEALTHY, lint 0 FAIL on a complete tree; lint exits 1 while any skill is half-authored): the two Phase 0 invocations
- Web-availability fact (user-level `~/.claude` never reaches web sessions): `claude-config-platform-reference` §6; README "Web availability (verified)"
- SessionStart missing-CLAUDE.md hook still present: read `hooks` in `C:\Dev\claude-config\settings.json`
- Sibling inventory (PowerShell, tested): `Get-ChildItem "$HOME\.claude\skills" -Directory -Filter 'claude-config-*' | Select-Object -ExpandProperty Name`
- Owner purpose statement (2026-07-07): a policy, not a file fact — reconfirm with the owner
