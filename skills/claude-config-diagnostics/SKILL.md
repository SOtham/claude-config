---
name: claude-config-diagnostics
description: Scripted structural health checks for this config repo - doctor.ps1 (links, settings, deny rules), lint-skills.ps1 (frontmatter), check-dist.ps1 (stale zips). Run before/after config changes.
---

# Claude-Config Diagnostics

Measure, don't eyeball. Three PowerShell scripts in this skill's `scripts\` folder turn "the config looks fine" into machine-checked facts: the canonical repo, the `~/.claude` link layer, the enforced `settings.json`, every skill's frontmatter, and the freshness of the claude.ai upload zips. This library exists to move top-tier discipline to cheaper-tier sessions — these scripts give any session tier the same objective health signal instead of a judgment call.

**Read-only guarantee:** all three scripts make zero writes anywhere — no files created, modified, or deleted; output goes to stdout only. Running them is always safe.

## 1. When to run

1. **Before any config change** — `doctor.ps1` confirms a clean baseline, so a later failure is attributable to your change (gates for the change itself: `claude-config-change-control`).
2. **After any config change** — all three; `check-dist.ps1` tells you exactly which zips to rebuild and re-upload.
3. **At the start of a maintenance session** — all three, before trusting any assumption about the setup.
4. **When something feels off** — run first, then triage the FAIL lines per `claude-config-debugging`.

## 2. The three scripts — exact invocations

**PowerShell** (tested 2026-07-08 under Windows PowerShell 5.1; both this `$HOME` junction path and the canonical `<clone>\skills\...` path work — each script derives the repo root from its own location and resolves the junction — a Windows directory link, here `~/.claude\skills` pointing at the repo's `skills\` folder):

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\claude-config-diagnostics\scripts\doctor.ps1"
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\claude-config-diagnostics\scripts\lint-skills.ps1"
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\claude-config-diagnostics\scripts\check-dist.ps1"
```

| Script | Checks | Notes |
| --- | --- | --- |
| `doctor.ps1` | Repo top-level files present; each expected `~/.claude` entry has the right link type (5 SymbolicLinks + `skills` Junction) and target — a real file/dir instead is a **WARN**, not FAIL, since 2026-07-10 (legitimate on an `install.ps1 -Mode Copy` install; suspicious on a link-mode one); `settings.json` parses and all 9 baseline secrets deny rules present; CLAUDE.md vs ~120-line budget (WARN only) | One-shot system health |
| `lint-skills.ps1` | Per `skills\<dir>`: SKILL.md exists; frontmatter (the `---`-delimited YAML block) parses; `name:` = folder name; `description:` non-empty and ≤200 chars; >160 lines is a WARN; duplicate names | Tolerates half-written skills: every broken state is a reported finding, never a crash |
| `check-dist.ps1` | Per skill: `~/.claude/dist/<name>.zip` exists and is newer than the newest file in the skill folder; orphan zips (zip without folder); WARNs if a second `dist\` exists inside the repo | A brand-new skill is EXPECTED to show `zip MISSING` until `sync.ps1` runs — as of 2026-07-08 the new `claude-config-*` skills all do |

**Exit codes** (all three): `0` = healthy — WARNs allowed; `1` = at least one FAIL. Read `$LASTEXITCODE` immediately after the call. WARN never flips the exit code.

Scripts travel inside the upload zip: `sync.ps1` packages each skill folder recursively (`Get-ChildItem $_.FullName -Recurse -File`), so `scripts\` ships in `claude-config-diagnostics.zip` automatically.

## 3. Interpretation guide

Real excerpts from the 2026-07-08 test runs (mid-authoring-campaign snapshots — folder counts were lower then; 25 folders as of 2026-07-09):

```
== Check B: ~/.claude links ==
[PASS] ~/.claude\CLAUDE.md is a SymbolicLink -> <clone>\CLAUDE.md
[PASS] ~/.claude\skills is a Junction -> <clone>\skills
== Check C: settings.json ==
[PASS] settings.json parses as JSON
[PASS] all 9 baseline secrets deny rules present
doctor summary: 0 FAIL, 0 WARN
result: HEALTHY                                          (exit code 0)
```

```
[FAIL] claude-config-diagnostics: SKILL.md missing        <- lint catching a half-written skill
lint summary: 23 folder(s) checked, 1 FAIL, 0 WARN        (exit code 1)
```

```
[FAIL] claude-config-architecture: zip MISSING (expected for a brand-new skill) - run sync.ps1, then upload claude-config-architecture.zip
dist summary: 23 skill(s), 15 zip(s); 8 missing, 0 stale; 8 FAIL, 0 WARN   (exit code 1)
```

| Finding | What it means | Where to go next |
| --- | --- | --- |
| doctor: `repo file MISSING` | Canonical repo damaged, moved, or renamed | Triage: `claude-config-debugging`; rebuild runbook: `claude-config-distribution` |
| doctor: `~/.claude entry MISSING` / `expected SymbolicLink, found ...` / `target ... does not match` | Link layer broken — Claude Code is reading stale config or none at all | Recreate links: `install.ps1` (or manual runbook in `claude-config-distribution`); triage first if cause unknown: `claude-config-debugging` |
| doctor WARN: `... is a real file, not a link` | Copy-mode install (expected — refresh via `install.ps1 -Mode Copy` after `git pull`) OR, on a link-mode machine, a link clobbered by a real file (debugging row i) | Know which install mode this machine uses; relink via `install.ps1` if it should be link-mode |
| doctor: `settings.json does NOT parse` | The ENFORCED layer is dead — deny rules may be inactive | Fix immediately; ship the fix through `claude-config-change-control` |
| doctor: `secrets deny rule MISSING` | Secrets protection silently weakened | Restore via `claude-config-change-control` (deny rules are a non-negotiable there); investigate how it happened: `claude-config-debugging` |
| doctor WARN: `CLAUDE.md is N lines - over the ~120-line budget` | Every session pays for the overage; adherence drops (maintainer-comment doctrine; Assumption — still unmeasured: the achieved M2 tested a description A/B, not budget effects) | Trim before adding more; budget rationale: `claude-config-architecture`; the trim is a change → `claude-config-change-control` |
| lint: `SKILL.md missing` / `empty` / `frontmatter never closed` | Half-written skill — possibly mid-authoring by another session | Finish or remove it; authoring standard: `claude-config-skill-authoring` |
| lint: `name '...' does not equal folder name` / `duplicate skill name` | Folder=name=zip coupling broken — upload matching will misbehave | Fix frontmatter per `claude-config-skill-authoring` |
| lint: `description is N chars (limit 200)` / no description | claude.ai will reject the upload; skill may never auto-load | Rewrite per the description recipe in `claude-config-skill-authoring` |
| lint WARN: `SKILL.md is N lines (>160 ...)` | Oversized body taxes loading and adherence | Move detail into `references/` or `scripts/` inside the skill folder |
| check-dist: `zip MISSING` | Skill never packaged — web sessions can't see it (expected for brand-new skills) | Run `sync.ps1` + upload: `claude-config-distribution` |
| check-dist: `zip STALE` | Local edits not yet in the zip — claude.ai serves the old version | Run `sync.ps1` + re-upload the named zips: `claude-config-distribution` |
| check-dist: `orphan zip` | Skill folder deleted or renamed; a stale upload may still be live on claude.ai | Reconcile per `claude-config-distribution` (remove zip and claude.ai upload if retired) |
| check-dist WARN: `second dist exists at <clone>\dist` | `sync.ps1` was invoked via its canonical repo path — it derives `dist\` from its invoked path, so the documented `$HOME\.claude\sync.ps1` invocation is load-bearing | `claude-config-distribution` owns this behavior; remove the repo-side copy |

## 4. What these scripts cannot measure

Structural health only. They prove the plumbing is intact — they say **nothing** about whether a skill actually triggers in a session or whether its instructions are followed. Adherence is a behavioral property; scripts cannot measure it. Behavioral evidence (trigger tests, adherence spot-checks, before/after evals) is `claude-config-validation`.

## When NOT to use this skill

- A FAIL line you cannot classify, or a failure with no FAIL line at all → `claude-config-debugging` (symptom→cause triage)
- Does a skill trigger? Is it followed? Any behavioral question → `claude-config-validation` — do not expect these scripts to answer it
- Actually rebuilding zips, re-uploading, recreating links → `claude-config-distribution`
- Deciding whether a change is allowed and shipping it → `claude-config-change-control`

## Provenance and maintenance

Written 2026-07-08. All three scripts ran clean that day via `powershell -ExecutionPolicy Bypass -File ...` — final run: doctor exit 0 HEALTHY; lint exit 0 (25 folders, 0 FAIL — an earlier same-day run correctly flagged this skill's own then-missing SKILL.md, excerpt above); check-dist exit 1 (10 new-skill zips genuinely missing, the expected pre-sync state). Linter edge cases (empty file, unclosed frontmatter, name mismatch, >200-char description, duplicates) were exercised against a synthetic broken-skills tree. Baselines hardcoded in the scripts WILL drift — re-verify before trusting:

- **Deny-rule baseline** (9 rules in `doctor.ps1` `$expectedDeny`, copied from `settings.json` 2026-07-08): `(Get-Content "$HOME\.claude\settings.json" -Raw | ConvertFrom-Json).permissions.deny` — rules may be *added* (then update `$expectedDeny` via `claude-config-change-control`); a removal is a change-control §2a red flag — surface to the owner, never update the baseline to match a removal.
- **~120-line CLAUDE.md budget** (in `doctor.ps1`): source is the HTML maintainer comment at the top of `CLAUDE.md` — re-read it: `Get-Content "$HOME\.claude\CLAUDE.md" -TotalCount 9`.
- **Expected `~/.claude` link inventory** (5 SymbolicLinks: CLAUDE.md, settings.json, sync.ps1, CLAUDE-SNIPPET.md, README.md + `skills` Junction): `Get-ChildItem "$HOME\.claude" -Force | Where-Object { $_.LinkType } | Select-Object Name, LinkType, Target`.
- **≤200-char description limit / >160-line guidance** (in `lint-skills.ps1`): limit owned by `claude-config-platform-reference`.
- **dist location** (`$HOME\.claude\dist` in `check-dist.ps1`): follows from `sync.ps1` deriving paths from its invoked location — re-read the `$root`/`$dist` lines of `<clone>\sync.ps1`; doctrine in `claude-config-distribution`.
