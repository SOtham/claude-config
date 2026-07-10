---
name: claude-config-research
description: Measured-adherence research program for this config library - predict-first hypotheses, trigger-recall corpus, refutation, experiment log. Use when building the eval harness or logging experiments.
---

# Claude-Config Research

The research program that replaces vibes-based config tweaking with numbers, and the methodology bar every config hypothesis must clear before adoption. Honest status up front: **the eval harness does not exist yet** — every step below is labeled `done`, `open`, or `candidate`, and nothing here claims a measurement that was never taken. The library's purpose (transfer top-tier engineering discipline to cheaper-tier sessions) makes this the frontier: without measurement there is no evidence the transfer works.

## 1. The gap — why current practice fails

Config and skill changes — here and everywhere — ship on anecdote: edit a description, notice it "seems to load now", ship. Three measurements are missing across the ecosystem:

| Missing measurement | Question it would answer |
| --- | --- |
| Trigger recall | For each realistic task phrasing, does the intended skill load — and do near-misses stay silent? |
| Regression detection | After editing a description or rule, did any previously-passing case silently break? |
| Adherence scoring | Once loaded, did the session's *behavior* follow the rule, at what rate, on which tier? |

The qualitative stopgap is this project's manual protocols — trigger tests, adherence spot-checks, before/after cases (see `claude-config-validation`; its own honesty rule caps manual results at "3+ consistent cases = evidence, still labeled qualitative"). `claude-config-architecture` lists "no adherence eval harness yet" as an open weak point. This skill is the plan to close it.

## 2. Why this repo can do better — the specific assets

1. **Small, closed skill set** — 25 `SKILL.md` files on disk (2026-07-08), enumerable in one directory listing. Exhaustive trigger-case coverage is actually feasible here, unlike open-ended prompt libraries.
2. **Deterministic structural checkers already scripted** — `skills\claude-config-diagnostics\scripts\` (`doctor.ps1`, `lint-skills.ps1`, `check-dist.ps1`) settle the machine-checkable half; measurement effort goes only to behavior (interpretation guide: `claude-config-diagnostics`).
3. **Headless mode as a test driver** — *headless mode* = running Claude Code non-interactively from a script. `claude-config-platform-reference` §7 doc-verified the flags: `-p/--print`, `--output-format json` (returns `result`, `session_id`, `total_cost_usd`), `--model`/`--effort` to pin the tier under test, `--bare` as the no-config baseline arm, `--allowedTools`/`--permission-mode` for unattended runs, `--max-budget-usd` as a spend cap. Cite that section; do not re-derive. Note: the binary is `C:\Users\User\.local\bin\claude.exe` — not on PATH in sandboxed sessions.
4. **A tested observability instrument for interactive sessions** — `claude-config-validation` §2 verified (2026-07-08) that session transcripts at `~/.claude/projects/<munged-cwd>/<session-id>.jsonl` record each skill load as `"name":"Skill","input":{"skill":"<name>"}`, greppable after the session. Whether headless runs leave the same trail is Step 2 below.
5. **Hooks as instrumentation points** — `candidate`, untested: a `PostToolUse` hook matching the Skill tool could log loads in real time (hook events: `claude-config-platform-reference` §3).

## 3. The methodology bar — every config hypothesis clears all four

1. **Predict observables BEFORE running.** Write down which task phrasings will load which skill, or which behavior will change, before the first test session starts. A prediction written after seeing results is a description, not a prediction — and it cannot fail, which is the problem.
2. **One mechanism must explain ALL observations, including negatives.** A description tweak that "worked" on 3 phrasings and silently broke 1 is not adopted; it is a finding to explain. If the explanation requires two unrelated mechanisms, the experiment is not understood yet.
3. **Adversarial refutation before adoption.** Assign a separate fresh session or subagent — never the session that authored the change, whose context is contaminated (see `claude-config-validation` §3) — one job: break the conclusion. Find a phrasing that misfires, a case where the new rule backfires, a tier where it degrades. Adoption requires the refutation attempt to fail *and be recorded*.
4. **Idea lifecycle — no silent deaths:** `candidate` → `trialed` (scoped to one repo first, protocol: `claude-config-validation` §6) → `adopted` (shipped via `claude-config-change-control`) OR `retired` with the negative result recorded. A retired idea with a written negative is a result; a quietly dropped one is a repeat experiment waiting to happen.

## 4. The experiment log — recording convention (`in use`)

This repo has no git history (weak point owned by `claude-config-architecture`), so if a result is not written to a file, it never happened. Convention: **`references\experiment-log.md` in this folder** — one dated entry per hypothesis with fields Hypothesis / Prediction (written before running) / Method / Result / Negatives / Refutation attempt / Verdict. Graduated from `candidate` to `in use` at entry #2 (per the log header rule); as of 2026-07-09 it holds entries #1 (authoring campaign, shipped unmeasured), #2 (observability), #3 (M1 baseline). Division of labor: per-case pass/fail detail for a specific skill belongs in that skill's `evals.md` per `claude-config-validation` §7; the experiment log records program-level lifecycle verdicts.

## 5. First three concrete steps in this repo

**Step 1 — trigger-recall case set. Status: `done` (the set), `unmeasured` (the runs).**
Artifact: `references\trigger-cases.md` in this folder — 33 cases: one should-load phrasing per the 25 skills on disk (derived from their real frontmatter descriptions, read 2026-07-08), 3 discrimination probes between confusable siblings, and 5 near-misses that should load nothing. Expected outcome: the fixed corpus every future measurement reuses, so runs are comparable across time. Run protocol is owned by `claude-config-validation` §3 (fresh session per case, never type `/<name>`).

**Step 2 — observability for automated runs. Status: `resolved` (confirmed 2026-07-09, experiment-log entry #2).**
Question was: can a script detect "skill X loaded" in a headless run? **Yes.** The pipeline below was run (two probes, model `claude-haiku-4-5`, ~$0.026 each) and the transcript carried both a `skill_listing` record (what was offered) and a `{"name":"Skill","input":{"skill":"<name>"}}` record when a skill loaded. Reproduce (PowerShell; needs a normal non-sandboxed shell):

```powershell
& "$env:USERPROFILE\.local\bin\claude.exe" -p "The nightly build started failing after yesterday's merge - find out why" --output-format json | Out-File "$env:TEMP\probe.json" -Encoding utf8
$t = Get-ChildItem "$HOME\.claude\projects" -Recurse -Filter *.jsonl | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Select-String -Path $t.FullName -Pattern '"name":"Skill"'   # 0 matches = model did not load a skill; >=1 = it did, with the skill name
```

Zero Skill records on a task whose description clearly matches a skill is a *real measurement* (the model declined to load it), not an observability failure — probe 1 produced exactly that on haiku. **Remaining sub-question before M1 scoring rules freeze:** this observable is the model-*invocation* path (a Skill tool call). Confirm whether description-based auto-*injection* can occur in headless mode *without* a Skill record (inspect whether skill body text enters context absent the call); if it can, M1 must score on both signals, not just the Skill record. Fallback instruments if a run ever leaves no trail: a `PostToolUse` logging hook (§2.5), or `--debug` output (`Unverified` — check `claude --help`).

**Step 3 — first measured experiment. Status: `done` (entry #4 — the `loops` A/B, adopted on a pre-registered rule); the pattern below is the standing protocol for every future description change.**
A/B one skill-description change: arm A = current description, arm B = candidate rewrite. Run the full trigger-case set against each arm, fresh session per case. **Blinded scoring**: the grader sees transcripts only, never which arm produced them. **Regression rule**: no case that passed under arm A may fail under arm B — a net-positive change that breaks an old case is a finding, not a win (§3.2). Verdict and numbers go in the experiment log; an adopted arm B ships via `claude-config-change-control`. The `loops`-vs-bundled-`loop` collision (entry #3) is the natural first A/B subject and the M2 candidate.

**The M1 instrument (`scripts/run-m1.sh`).** Classification mode: tools disabled, model outputs the one best-matching skill name (or NONE), answer read from the returned JSON — this isolates *description discriminability* and sidesteps two pitfalls found the hard way (entry #3): a transcript-flush race that faked 0% recall, and mid-run 429 session limits. Run: `CLAUDE=/path/to/claude.exe bash scripts/run-m1.sh <model-id>`. Note classification (does the description discriminate?) is a *different* question from invocation (does the model emit a Skill call, where bundled skills can shadow personal ones) — measure the one your hypothesis is about.

## 6. Falsifiable milestones — you have a result when…

- **M1** (`achieved` 2026-07-09, entry #3): trigger recall measured on the 33-case corpus, both tiers, via the rerunnable `scripts/run-m1.sh` — classification recall 33/33 (haiku) and 33/33 (sonnet). Re-run after any description change to detect regressions.
- **M2** (`achieved` 2026-07-09, entry #4): the `loops` description was differentiated from the bundled `loop` skill and adopted on a measured A/B — pre-registered adoption rule, 34/34 both tiers, zero regressions, invocation probe confirming the documented division of labor.
- **M3** (`adopted` 2026-07-10, entry #5): the trigger-recall suite is a written `claude-config-change-control` ship-checklist gate for every description/routing change (first enforced instance: entry #4). It stays "adopted", not "proven", until several changes have actually passed through it.

Milestones are about measurements *existing*, not hitting invented targets — the first M1 run sets the baseline; no recall percentage is promised in advance.

## 7. Where hypotheses come from

- Failures observed in real sessions — the settled-incident chronicle in `claude-config-debugging` is the symptom source.
- The cheaper-tier campaign's failure-mode table — `claude-config-model-uplift`.
- Community research — README credits community research (2026-07) for the workflow skills; new external findings enter as `candidate` entries, never as adopted rules.

## When NOT to use this skill

- Day-to-day manual evidence for a specific change (trigger test, spot-check) → `claude-config-validation`
- Running the cheaper-tier uplift campaign → `claude-config-model-uplift`
- Shipping an adopted change (gates, sync, re-upload) → `claude-config-change-control`
- Platform facts: headless flags, hook events, transcripts, skill mechanics → `claude-config-platform-reference`
- Structural health scripts and their interpretation → `claude-config-diagnostics`

## Provenance and maintenance

Written 2026-07-08 against the repo state on that date (25 SKILL.md files on disk — the last meta-layer siblings landed during authoring; local Claude Code 2.1.195). Re-verify before trusting:

- Skill inventory (PowerShell): `(Get-ChildItem "$HOME\.claude\skills" -Directory).Count` and per-folder `Test-Path` of `SKILL.md` — then check `references\trigger-cases.md` still covers every description
- Headless flags and binary: `claude-config-platform-reference` §7; `& "$env:USERPROFILE\.local\bin\claude.exe" --version` (PowerShell)
- Transcript instrument and record shape: `claude-config-validation` §2 and its provenance notes
- Diagnostics scripts exist: `Get-ChildItem "$HOME\.claude\skills\claude-config-diagnostics\scripts"` (PowerShell)
- M1 harness exists and reruns: `bash scripts/run-m1.sh <model-id>` (needs the `claude` CLI; set `CLAUDE=` to its path); compare against entry #3's 33/33
- Experiment-log convention adoption: read `references\experiment-log.md` — if entries beyond #1 exist, the convention graduated from `candidate`; update §4
- Milestone status: the experiment log is the source of truth — an M1/M2 entry there outdates the `open` labels above
