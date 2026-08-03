---
name: claude-config-skill-authoring
description: Author or edit a skill in this config library - new-vs-extend decision, naming rules, SKILL.md template, description recipe, checklist. Use when creating, changing, or reviewing any skill here.
---

# Claude-Config Skill Authoring

How to author or edit a skill in `<clone>\skills\` at the house standard. A *skill* here is a folder holding a `SKILL.md`: its `description` is visible to every session as the auto-load trigger, and its body loads only when relevant (or when invoked as `/<name>`). This library exists to transfer top-tier engineering discipline to cheaper-tier sessions — a skill earns its place only if it changes what a lightweight-tier session actually does. Work the sections in order.

## 1. Decide: new skill, extension, or nothing

1. **Covered elsewhere already?** Claude Code bundled skills (`/code-review`, `/simplify`, `/verify`, `/security-review`) and Anthropic's official document/frontend skills are deliberately not duplicated here (README doctrine). If one of them owns the job → write nothing.
2. **Fact or gate, not a method?** A standing fact or constraint belongs in `CLAUDE.md` (always loaded, tightly budgeted); a rule that must be *enforced* belongs in `settings.json`. Layer split: see `claude-config-architecture`. Skills carry *procedures*.
3. **An existing skill owns the situation?** Check the Skill Routing table in `CLAUDE.md` and each candidate's `description`. If your material serves that skill's one job → add a section there instead of a new skill, and keep it lean.
4. **Otherwise a new skill — only if all three hold:** (a) the situation recurs, (b) there is a repeatable method or decision rule to teach (not just facts), (c) a lightweight-tier session gets it wrong without the guidance.

**One skill = one job.** State the job in a single sentence with no "and also". If the draft description needs two jobs, split or cut one.

## 2. Naming rules

- **kebab-case** (lowercase words joined by hyphens), e.g. `root-cause`, `claude-config-validation`.
- **Folder name = frontmatter `name` = zip name.** Why: `sync.ps1` derives everything from the folder — it packages each `skills/<folder>/` into `dist/<folder>.zip` with `<folder>/` as the zip-root prefix on every entry — and claude.ai identifies an uploaded skill by its name, so a mismatch breaks matching between the local skill and its upload. (Platform-side naming and upload constraints: see `claude-config-platform-reference`.)
- **Prefix convention:** `claude-config-*` marks meta-layer skills about maintaining this library itself; generic engineering-method skills (`writing-code`, `architect`, …) carry no prefix because they apply in any repo. Pick the side your skill belongs to and follow it.

## 3. SKILL.md template (annotated)

Generalized from the existing skills in this repo. Frontmatter (the YAML block between the `---` lines) uses exactly two keys — `name` and `description` — in every existing skill. Delete the `#` and `<!-- -->` annotation lines when you copy.

```markdown
---
# MUST equal the folder name (Section 2)
name: my-skill-name
# ≤200 chars, the auto-load trigger — craft per Section 4
description: <what it does, concrete verbs> - <3-5 method keywords>. Use when <trigger situations>.
---

# My Skill Name

<!-- Charter: 1-3 sentences — the job plus its rule of engagement
     (e.g. "Speculative fixes are forbidden"). Every house skill opens this way. -->

## Step 1 — <first phase>
<!-- Imperative runbook voice. Numbered steps, decision rules, tables,
     checklists. No filler, no motivation essays — one clause of "why"
     attached to a rule is enough. -->

## Anti-patterns
<!-- Or "Judgment calls" / "Discipline" / "Rules of thumb" — the closing
     section names the mistakes the skill exists to prevent. -->

## When NOT to use this skill
<!-- Meta-layer (claude-config-*) skills only: point each near-miss
     situation at the sibling that owns it. -->

## Provenance and maintenance
<!-- Meta-layer skills only: verification date + one-line re-check
     commands for every volatile fact. -->
```

**Size:** the method skills run 28–53 lines today (verified 2026-07-07); meta-layer skills may run up to ~150 (house guidance; `lint-skills.ps1` WARNs above 160 — thresholds: `claude-config-diagnostics`). Long reference material goes in extra files inside the same skill folder (e.g. `references/`, `scripts/`) that the body points to — `sync.ps1` packages the folder recursively, so they ship in the zip.

## 4. Craft the description

The `description` is the only part of the skill every session sees — it alone decides whether the body ever loads. Front-load *when to use*, in the words a user would actually type.

**Recipe:** `<what it does, concrete verbs> - <3–5 keyword nouns from the method>. Use when <trigger situations>.` House limit **≤200 characters** — docs-advised and lint-enforced here; NOT rejected at upload (201 accepted verbatim, 2026-07-10 — facts owned by `claude-config-platform-reference` §5).

**Good** — verbatim from `skills/root-cause/SKILL.md` (190 chars):

> Systematic debugging - reproduce, isolate by bisection, trace the dependency chain, prove the cause before fixing. Use when investigating bugs, test failures, regressions, or weird behavior.

Why it works: the job in two words up front; method keywords (reproduce, bisection, dependency chain) a request would echo; the "Use when" clause lists the exact words users type ("bug", "test failure", "regression", "weird behavior").

**Bad** — do not write this (invented counter-example):

> This skill provides comprehensive best practices, helpful guidance, and useful tips for various debugging scenarios and other related engineering situations.

Why it fails: zero trigger keywords ("comprehensive", "helpful", "various" match nothing a user types); never says *when* to load it; "and other related" advertises more than one job; burns characters on filler ("This skill provides").

**Count before shipping** (PowerShell, tested):

```powershell
$d = (Get-Content "$HOME\.claude\skills\<name>\SKILL.md" | Select-String '^description:' | Select-Object -First 1).Line -replace '^description:\s*',''; $d.Length
```

## 5. Authoring checklist (in order)

1. Run the Section 1 decision; write the one job down in one sentence.
2. Read 2–3 neighboring skills (e.g. `writing-code`, `root-cause`, `prompt-craft`) to absorb the voice before drafting.
3. Create `skills/<name>/SKILL.md` from the Section 3 template; confirm folder name = frontmatter `name`.
4. Write the description per Section 4; verify ≤200 chars with the counter one-liner.
5. Write the body as a procedure a zero-context engineer or lightweight-tier session can execute without asking questions; define jargon at first use.
6. Verify every command, path, and limit you state by running or reading it in THIS environment (Windows PowerShell 5.1 — no `&&`/`||`; label each block PowerShell or bash). Label anything unverified.
7. Skill ships `scripts\`? Add a fixture-based suite at `<clone>\tests\<name>.tests.sh` (repo `tests\` sits outside `skills\` so it never ships in the zip; `tests\run-all.sh` picks it up by name) and run it green before shipping — details in `claude-config-diagnostics`.
8. One home per fact: if a sibling skill owns a fact, write one line plus "see `<sibling>`" — never a second full copy.
9. Cut every line that would not change a lightweight-tier session's behavior. Shorter skills are followed better (house doctrine per the CLAUDE.md maintainer comment; Assumption — still unmeasured: the achieved M1/M2 tested trigger recall, not body adherence).
10. Ship it through `claude-config-change-control` — change classification, gates, and the sync/re-upload protocol live there.
11. Prove it triggers per `claude-config-validation` — trigger tests and adherence spot-checks live there.

## When NOT to use this skill

- Writing prompts, agents, or CLAUDE.md files for an application or another repo → `prompt-craft`
- General documentation (README, ADR, runbook, API docs) → `doc-craft`
- Deciding whether a config change is allowed, and shipping it → `claude-config-change-control`
- Platform facts: frontmatter fields, upload limits, skill discovery → `claude-config-platform-reference`
- Zip/sync/upload mechanics, rebuilding the setup → `claude-config-distribution`

## Provenance and maintenance

Written 2026-07-07 against the repo state on that date (15 method skills, single `SKILL.md` per folder, frontmatter keys `name` + `description` only). Inventory as of 2026-08-03: 27 folders — 17 method skills + 10 `claude-config-*` meta skills; structure and frontmatter keys unchanged. Re-verify volatile facts before trusting them:

- Skill inventory and line counts (PowerShell, tested): `Get-ChildItem "$HOME\.claude\skills" -Directory | ForEach-Object { "{0}: {1} lines" -f $_.Name, (Get-Content (Join-Path $_.FullName 'SKILL.md')).Count }`
- Folder→zip naming coupling: read the header and `$name` lines of `<clone>\sync.ps1`
- Any skill's description length: the counter one-liner in Section 4
- ≤200-char description limit and other upload constraints: `claude-config-platform-reference`, or attempt an upload at claude.ai → Settings → Capabilities → Skills
- House editing constraints summary: "Editing a skill" section of `<clone>\README.md`
