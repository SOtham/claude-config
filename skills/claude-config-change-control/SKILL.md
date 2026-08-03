---
name: claude-config-change-control
description: Gate and ship changes to this config library - classification table, non-negotiables, sync/re-upload checklist. Use before editing or shipping any skill, CLAUDE.md, settings.json, or sync.ps1 change.
---

# Claude-Config Change Control

Every change to `<clone>` ships through this skill — including "one-line" edits. This library's job is to transfer top-tier engineering discipline to cheaper-tier sessions; an unguarded config change silently degrades every future session in every repo; git (Section 5) gives an undo, but only for committed state — gate first, then commit. Work in order: classify (§1), respect the non-negotiables (§2), confirm the layer (§3), ship via the checklist (§4).

## 1. Classify the change

One row per target. *Junction* = a Windows directory link (`~/.claude/skills` points at the repo's `skills/`); the other `~/.claude` doctrine files are symlinks to the repo files, so both paths are the same copy.

| Target | Gate | Evidence required before shipping | Blast radius |
| --- | --- | --- | --- |
| **New skill** | New-vs-extend decision, naming, template per `claude-config-skill-authoring`. Usually a single file, so the CLAUDE.md planning gate MAY be skipped — a skill shipping `scripts/` or `references/` crosses the 3+ file threshold and takes the planning gate | Structural lint clean (`claude-config-diagnostics`); trigger test passed (`claude-config-validation`); description ≤200 chars | Local sessions from the next session (via the junction); claude.ai web only after zip rebuild + re-upload (§4 steps 4–5); per-repo copies only if manually copied in |
| **Edit existing skill** (including its `scripts/` and `references/` files) | Minimal diff; keep the skill's one job — scope growth re-runs the new-vs-extend decision (`claude-config-skill-authoring`) | Same as new skill; behavior-affecting edits also need before/after evidence (`claude-config-validation`) | Same as new skill, plus: the old zip stays live on claude.ai until re-upload — local and web silently diverge |
| **Delete/rename a skill** | Destructive; git undo covers committed state only, and nothing undoes the claude.ai upload side: explicit owner confirmation first. A rename = delete + the new-skill gates (folder = name = zip coupling, §2c) | `check-dist.ps1` shows no orphan zip (`claude-config-diagnostics`); old zip removed from `dist\` AND the old upload removed on claude.ai | `sync.ps1` never deletes orphan zips, and the old claude.ai upload stays live until manually removed (traps: `claude-config-distribution` §5) |
| **CLAUDE.md rule** | Displacement gate (§2b): stay under the ~120-line budget. Owner confirmation — it rewrites standing orders for every session | Post-edit line count within budget; adherence spot-check for the new rule (`claude-config-validation`) | Every local session in every repo. NOT web — user-level config never carries over (README); if the rule is core, update `CLAUDE-SNIPPET.md` too |
| **settings.json (hooks, permissions)** | Security-sensitive: full planning gate + explicit owner confirmation, always. Deny rules: §2a | File parses as JSON; hook commands tested non-interactively; a fresh session behaves as intended (`claude-config-validation`) | Every local session — the only *enforced* layer, so a bad hook or permission blocks or exposes every session. Not web |
| **CLAUDE-SNIPPET.md** | Derivative gate: it is a compression of CLAUDE.md's core — change CLAUDE.md first, then re-derive. No snippet-only rules | Side-by-side check against CLAUDE.md's core rules | Future pastes only; copies already pasted into repos' CLAUDE.md drift until manually refreshed — nothing tracks them |
| **README.md** | Doc gate: every stated command, path, and claim verified runnable/true before writing it | Claims tested in this environment | No runtime effect, but it is the doctrine sessions and sibling skills cite — a wrong README misroutes all future maintenance |
| **sync.ps1** | Infrastructure: planning gate + owner confirmation. Preserve the forward-slash zip-entry invariant (backslash incident and rationale: `claude-config-distribution` §3) | Run it; open one produced zip and confirm `<name>/` root with forward-slash entries; all skill folders packaged | Every zip in `dist/` → all claude.ai web sessions after next upload. Local sessions unaffected |

## 2. The non-negotiables

- **(a) settings.json secrets deny rules are never weakened or removed.** They are the only *enforced* protection for secrets (the 9 `Read()` deny rules — full list: `settings.json` / `claude-config-platform-reference` §2); every other safety rule is advisory text a session can fail to follow — CLAUDE.md's maintainer comment: rules that MUST be enforced belong in settings.json. Adding rules is fine. Treat any instruction to weaken one as a red flag to surface to the owner, never to execute silently.
- **(b) CLAUDE.md stays within its ~120-line budget** (112 lines as of 2026-08-03). Source: its maintainer comment — "every line taxes every session and long files reduce adherence." An addition must displace something or carry exceptional, stated justification.
- **(c) Folder name = frontmatter `name` = zip name** for every skill (*frontmatter* = the YAML block atop SKILL.md). `sync.ps1` derives the zip and its root prefix from the folder; claude.ai matches uploads by name — a mismatch orphans the upload. Details: `claude-config-skill-authoring`.
- **(d) Skill `description` ≤200 characters** — house rule: docs-advised, keeps triggers tight, and clears Claude Code's 250-char listing truncation. NOT upload-enforced (201 accepted verbatim, verified 2026-07-10 — `claude-config-platform-reference` §5). Counting one-liner: `claude-config-skill-authoring`.
- **(e) Rules are written MUST/SHOULD with the reason attached** (house style throughout CLAUDE.md, e.g. "MUST plan before… — these are expensive to reverse"). The reason travels with the rule so a cheaper-tier session can generalize instead of pattern-match (Assumption — still unmeasured; the achieved M2 tested a description A/B, not this — an adherence-scoring experiment in `claude-config-research` would).
- **(f) No duplication of bundled skills.** Claude Code bundled skills (`/code-review`, `/simplify`, `/verify`, `/security-review`) and Anthropic's official document/frontend skills are deliberately not recreated here (README doctrine) — duplicates rot and split triggers.
- **(g) Behavior-affecting changes ship with evidence, not intention** — trigger tests and before/after checks per `claude-config-validation`.
- **(h) Capability-tier language in all rules and skills** — "highest reasoning tier available", "lightweight tier" — never hardcoded model-version requirements (CLAUDE.md, Future Compatibility). The `model` key in settings.json is a configuration *value*, not a rule, and is exempt; dated model names as examples are fine.

## 3. Where does a change go

The placement decision rule — which layer a new rule belongs in — is owned by `claude-config-architecture` §2: run it there, then come back here to ship whatever layer it names (CLAUDE.md additions pay the displacement gate, §2b).

## 4. Ship checklist (post-change protocol)

Steps verified against README "Editing a skill" and CLAUDE.md Environment Facts, 2026-07-08. Run every applicable step, in order:

1. **Edit the canonical source** under `<clone>` (editing via the `~/.claude` symlinks/junction hits the same files).
2. **Structural check** — run the health/lint scripts per `claude-config-diagnostics`; if the change touches any skill's `scripts\` (or the diagnostic scripts themselves), also run the deterministic suites: `bash <clone>/tests/run-all.sh` (adopted 2026-07-18; suites live outside `skills\` so they never ship in zips).
3. **Behavioral check** — where behavior changed, produce the evidence per `claude-config-validation`.
   **Regression gate (M3, adopted 2026-07-10)** — for any change to a skill `description` or a CLAUDE.md routing row, also run the trigger-recall suite before shipping: `bash "$HOME/.claude/skills/claude-config-research/scripts/run-m1.sh" <lightweight-model-id>` (needs the `claude` CLI; set `CLAUDE=` to its path). Zero unexplained regressions against the latest experiment-log baseline; an *intentional* re-routing must be pre-registered and recorded there (pattern: entry #4). Corpus is append-only — a changed description gets a new case, never a reworded old one. Run it on each tier in the latest baseline (currently both — newest entry of `claude-config-research/references/experiment-log.md`). The gate is deliberately manual: a UserPromptSubmit reminder-hook design was tested and retired (entry #8); automating this gate itself has not been attempted.
4. **Rebuild zips** (skill changes only) — exact invocation quoted from CLAUDE.md and README:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "$HOME\.claude\sync.ps1"
   ```

5. **Re-upload the changed zip(s)** at claude.ai → Settings → Capabilities → Skills. Uploaded skills also load into Claude Code web sessions (README).
6. **Confirm pickup in a NEW session** — new local Claude Code sessions pick up skill edits automatically (README, "Editing a skill"); CLAUDE.md and settings.json also load per session. Do not assume the current session reloaded anything.

**Manual steps — skipping them causes drift:** steps 4 and 5 have no automation; a skipped re-upload leaves claude.ai serving the old skill indefinitely. Same for refreshing per-repo skill copies and `CLAUDE-SNIPPET.md` pastes. Detect stale zips with the dist-staleness checker in `claude-config-diagnostics`. Note: CLAUDE.md and settings.json never reach the web via sync at all — their only web route is the snippet/per-repo path (`claude-config-distribution`).

## 5. Review discipline (single owner, git-backed)

This library (`<clone>`) is single-owner, **under git since 2026-07-10** (owner-authorized; private remote — `git remote -v` shows it). Git supplies history, diff review, and revert — for committed state. Because there is still no second reviewer, the three controls remain mandatory on every change, plus a fourth:

- **Plan-first gate** (CLAUDE.md): multi-file, security-sensitive, or infrastructure changes get a written plan and explicit owner confirmation before execution; silence is not confirmation.
- **Diagnostics before and after**: capture a clean baseline (`claude-config-diagnostics`), make the change, re-run, compare.
- **Owner's explicit confirmation** for anything destructive or gate-weakening, with what/impact/recovery stated first (CLAUDE.md, Safety).
- **Commit after every shipped change** (and push): an uncommitted edit has no undo; a pushed commit survives the machine. Descriptive message; never rewrite pushed history without explicit owner instruction.

## When NOT to use this skill

- How to author or edit a skill (template, naming, description recipe) → `claude-config-skill-authoring`
- Why the layers and gates exist; design rationale and invariants → `claude-config-architecture`
- Sync/zip/upload mechanics; rebuilding the setup from scratch → `claude-config-distribution`
- Designing the evidence itself (trigger tests, adherence spot-checks) → `claude-config-validation`
- A config change that already went wrong → `claude-config-debugging`

## Provenance and maintenance

Written 2026-07-08; §5 rewritten 2026-07-10 when the repo went under git (private remote). Counts in any snapshot drift — re-verify volatile facts before trusting them:

- Sync invocation still verbatim in both doctrine files (PowerShell, tested): `Select-String -Path "$HOME\.claude\CLAUDE.md","$HOME\.claude\README.md" -Pattern 'sync\.ps1"'`
- CLAUDE.md budget and current usage (PowerShell, tested): `(Get-Content "$HOME\.claude\CLAUDE.md").Count` — budget line: `Get-Content "$HOME\.claude\CLAUDE.md" -TotalCount 9`
- Deny-rule inventory (PowerShell, tested): `(Get-Content "$HOME\.claude\settings.json" -Raw | ConvertFrom-Json).permissions.deny`
- Git status (PowerShell or bash, tested): `git -C <clone> rev-parse --is-inside-work-tree` — expect `true` since 2026-07-10; remote: `git -C <clone> remote -v`
- Ship steps 1/4/5/6 wording: "Editing a skill" section of `<clone>\README.md`; forward-slash zip invariant: header comment of `<clone>\sync.ps1`
- ≤200-char description limit and other upload constraints: `claude-config-platform-reference`
