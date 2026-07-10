---
name: claude-config-validation
description: Evidence discipline for config and skill changes - trigger tests, adherence spot-checks, before/after cases, scoped trials. Use when proving a skill loads or a rule changed behavior.
---

# Claude-Config Validation

What counts as evidence that a change to this config library (a skill, `CLAUDE.md`, `settings.json`) actually worked, and the manual protocols that produce it. Honest premise: **today this project's validation is qualitative and manual** — the quantitative measured-adherence harness is the research frontier (see `claude-config-research`). This library exists to make cheaper-tier sessions work at top-tier standard, so "worked" always means *observed behavior changed*, never "the edit reads well".

## 1. Two classes of checks

| Class | Question | Owner |
| --- | --- | --- |
| Structural | Files, frontmatter, links, zip staleness — machine-checkable | `claude-config-diagnostics` (scripts + interpretation) |
| Behavioral | Does a session load the right skill and then follow it? | This skill |

Run structural checks first: a behavioral test cannot pass if, e.g., the skill's description was dropped from the model's skill listing — `/doctor` reports shortened/dropped descriptions (verified from docs 2026-07-08; platform facts: `claude-config-platform-reference`).

## 2. The measurement instrument — how to SEE a skill load

Mechanism (verified from https://code.claude.com/docs/en/skills, fetched 2026-07-08): every session carries all skill *descriptions* in context; a skill's *body* enters context only when the model (or you) invokes it via the Skill tool. So "did it load" = "was there a Skill tool invocation". Observation options, strongest first:

1. **Transcript grep — tested 2026-07-08, use as ground truth.** Each session is logged to `~/.claude/projects/<munged-cwd>/<session-id>.jsonl`, and a load is recorded as `"name":"Skill","input":{"skill":"<name>"}`. After the test session ends:

   ```powershell
   # PowerShell — skills invoked in the newest session for one project dir
   $t = Get-ChildItem "$HOME\.claude\projects\<munged-cwd>" -Filter *.jsonl | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   Select-String -Path $t.FullName -Pattern '"name":"Skill","input":\{"skill":"([^"]+)"' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
   ```

   Empty output = no skill loaded. Find `<munged-cwd>` by listing `~/.claude/projects` — path punctuation becomes `-` (e.g. `C:\Dev\claude-config` → `c--Dev-claude-config`).
2. **Watch the live session** for the Skill tool call. That the interactive UI renders it visibly is Unverified — calibrate once by running a case and cross-checking with the grep above.
3. **Distinctive artifact in the output** — e.g. the `## Proposed Architecture & Implementation Plan` header only `architect` produces. This is evidence the body was *followed*, not merely loaded.
4. **Asking the model** "did you load skill X?" — self-report, NOT evidence (Section 7). Use only to cross-check 1–3.

## 3. Trigger-test protocol (does the description fire?)

Run for every `description` change and every new skill.

1. **Before editing**, write down 3–5 realistic task phrasings that SHOULD load the skill and 1–2 near-misses that should NOT. Example for `root-cause` — should-load: "tests started failing after my change"; near-miss: "write a test for this function" (that's `test-craft`). Keep them in the case file (Section 7).
2. Make the edit.
3. Test in a session that did NOT make the edit. The editing session's context holds the draft and the discussion, so it "triggers" from conversation memory, not from the description listing. (README: new sessions pick up skill edits automatically; official docs 2026-07-08 additionally document live change detection inside a running session — either way, the *editing* session is contaminated, so use a fresh one.)
4. Present each phrasing as a natural task. NEVER type `/<name>`, never say "load skill X". One phrasing per fresh session — once a body loads it stays in context for the rest of the session (docs), poisoning later cases.
5. Record load / no-load per case with the Section 2 instrument.
6. **Ship rule: every should-load case triggers AND every near-miss doesn't.** Near-miss triggers → sharpen the description (recipe: `claude-config-skill-authoring`). Should-load misses → add the exact keywords the phrasing used.

## 4. Adherence spot-check protocol (did behavior change?)

For a rule or skill meant to change what a session *does*. Loading is necessary but not sufficient — the docs note skill content can sit in context while the model chooses other approaches.

1. **Define the observable BEFORE running** — one binary sentence a grader can check without judgment. Good observables (all from CLAUDE.md rules): "states the root cause in one sentence before any fix"; "plan appears under `## Proposed Architecture & Implementation Plan` and waits for `y`"; "final message says what was verified and what was not".
2. Run a representative task in a fresh session. If the change targets cheaper-tier uplift, run it on the lightweight tier — that is the tier this library exists to lift (campaign method: `claude-config-model-uplift`).
3. Grade against the observable, not vibes. Pass/fail per case.
4. Weight honestly: **1 case = anecdote; 3+ consistent cases = evidence worth acting on — still labeled qualitative.** Numbers with error bars wait for the harness (`claude-config-research`).

## 5. Before/after discipline

Apply `prompt-craft`'s eval loop to config changes: collect the cases BEFORE editing, run them for a baseline, edit, then re-run the SAME cases. A fix that breaks a previously-passing case is a regression, not a win — find which instruction now conflicts instead of stacking more rules. Full loop: `prompt-craft`.

## 6. Scoped trial before global promotion

Trial a risky new rule or skill in ONE project first — its `.claude/skills/` or project CLAUDE.md (locations and setup: `repo-setup`) — and promote to this global library only through `claude-config-change-control`. Gotcha (verified from docs 2026-07-08): on a name collision, a personal `~/.claude/skills/` skill **overrides** the project-level one — so trial a variant of an existing global skill under a different name, or the global copy silently wins.

## 7. Pass/fail honesty rules

- No claiming success without observed behavior. "The model said it would comply" is not evidence; neither is "the edit reads well".
- A passed trigger test proves loading, not adherence. Claim only what the test measured.
- Negative results get recorded, not discarded — they are the regression baseline for Section 5. Convention (candidate): keep the case list plus dated pass/fail one-liners in an `evals.md` inside the skill's own folder (it ships in the upload zip via `sync.ps1`, so keep it terse); for CLAUDE.md/settings changes, attach cases to the change record per `claude-config-change-control`. This repo has no git history to hold evidence (see `claude-config-architecture`): if a result isn't written to a file, it never happened.
- Date-stamp every recorded result — platform behavior drifts, and undated evidence cannot expire.

## When NOT to use this skill

- Structural, machine-checkable health checks and scripts → `claude-config-diagnostics`
- Building the quantitative measured-adherence harness → `claude-config-research`
- Deciding whether a change is allowed and shipping it (sync, re-upload, verify) → `claude-config-change-control`
- Campaign-level adherence work for cheaper-tier sessions → `claude-config-model-uplift`
- Writing or fixing the description/body under test → `claude-config-skill-authoring`

## Provenance and maintenance

Written 2026-07-08. Re-verify volatile facts before trusting them:

- Skill loading mechanics (descriptions always in context, body loads via Skill tool, live change detection, `/doctor` listing report, project-vs-personal precedence): re-fetch https://code.claude.com/docs/en/skills
- Transcript location and record shape: `Get-ChildItem "$HOME\.claude\projects"`, then `Select-String` any `.jsonl` for `"name":"Skill"` (tested 2026-07-08 — found a real `usage-credits` invocation). The Section 2 pattern assumes `"name"` and `"input"` are adjacent in the JSON; if it stops matching, fall back to `-Pattern '"name":"Skill"'` and read the matching lines.
- New-session pickup claim: "Editing a skill" step 1 in `C:\Dev\claude-config\README.md`; `sync.ps1` header states the same
- Adherence observable examples: Debugging, Planning Gate, and Verification sections of `C:\Dev\claude-config\CLAUDE.md`
- `evals.md` convention: candidate — check any skill folder for the file to see whether it was adopted
