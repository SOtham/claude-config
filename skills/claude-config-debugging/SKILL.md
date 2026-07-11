---
name: claude-config-debugging
description: Symptom-to-fix triage for this config library - skill not loading, /name missing, upload rejected, hook silent, settings ignored, UTF-16 garbling. Use when the Claude setup misbehaves.
---

# Claude-Config Debugging

When this config setup misbehaves — a skill won't load, an upload is rejected, a hook stays silent — do not guess. Find the symptom in the triage table, run its discriminating test (a read-only check that separates the candidate causes), then apply the fix or follow the cross-reference. Never re-fight an incident the chronicle marks settled. Written so a lightweight-tier session can triage without re-deriving the system.

Jargon: a **symlink** is a file that points at another file; a **junction** is the Windows directory equivalent; **frontmatter** is the YAML block between `---` lines atop a `SKILL.md`; a **BOM** (byte-order mark) is the leading bytes that declare a text file's encoding; **dist zips** are the claude.ai upload packages `sync.ps1` builds into `~/.claude/dist/`.

## 0. First move

Structural checks are scripted — run the `claude-config-diagnostics` scripts before manual triage; return here when a script flags something or the symptom is behavioral.

## 1. Triage table

Tests T1–T7 are spelled out in Section 2 with real, verified output.

| # | Symptom | Most likely cause(s) | Discriminating test | Fix |
| --- | --- | --- | --- | --- |
| a | Skill never auto-loads when relevant | Description lacks the words requests actually use; `disable-model-invocation: true` in frontmatter; skill not visible at all | In-session `/skills` (T7): listed? user-only badge? Then read its `description:` line against the prompt that should have triggered it | Listed but never invoked → rewrite description per `claude-config-skill-authoring` §4, prove with a trigger test (`claude-config-validation`). Not listed → treat as row b |
| b | `/name` not found in a local session | Skill folder missing/renamed — the **directory name** is the `/command` name, frontmatter `name` is display-only (`claude-config-platform-reference` §4); skills junction broken; a brand-new top-level skills *directory* created mid-session (the one restart case) | Folder exists under `~/.claude\skills\`? Then T1 | Restore/rename the folder; relink per `claude-config-distribution`; new session only for the new-directory case |
| c | Skill missing in a claude.ai/web session | **Expected** — user-level `~/.claude` never carries to web (`claude-config-platform-reference` §6; primary source: README "Web availability (verified)") | Was this skill's zip ever uploaded at claude.ai → Settings → Capabilities → Skills? (observation — no CLI check exists) | Upload `dist/<name>.zip`, or commit a per-repo copy — routes: `claude-config-distribution` |
| d | Skill upload rejected at claude.ai | Description over 200 chars; zip not built by `sync.ps1` (backslash entries — incident I1); folder/frontmatter name mismatch | Char-count one-liner in `claude-config-skill-authoring` §4; T4; T2 | Trim description; rebuild with `sync.ps1` only; rename to match |
| e | Edits to a skill not picked up | Local: per docs, live edits normally take effect within the current session (`claude-config-platform-reference` §4); README's "new session picks it up" is the guaranteed-weaker fallback. Web: the uploaded zip is stale | Check `/skills` (T7) in-session; if still stale, open a new session | New session locally if live pickup fails. Web: rebuild + re-upload (post-change protocol: `claude-config-change-control`) |
| f | SessionStart hook doesn't fire / shows nothing | Silence is **healthy** in repos that have a CLAUDE.md (the hook only speaks when one is missing); else settings.json invalid or hook command erroring | T6 (run the hook standalone), T3; in-session `/hooks` and `claude --debug hooks` (T7) | If T6 behaves as specified, the hook is fine. Else fix settings.json; hook edits are picked up automatically by the file watcher (hooks docs, see Provenance) |
| g | settings.json key seems ignored | JSON syntax error; same key overridden by a closer scope (repo `.claude/settings.json` / `settings.local.json`); key put in `~/.claude.json` (app state, not settings); invalid key name | T3; `/doctor` and `/status` (T7); grep the repo's `.claude/settings*.json` for the same key | Fix the JSON or move the key. Precedence rules: `claude-config-platform-reference` |
| h | CLAUDE.md rule loaded but not followed | Config is fine — CLAUDE.md is context, not enforcement; this is an adherence problem | `/memory` (T7) lists the file AND the rule is present verbatim in `<clone>\CLAUDE.md` | Not a config bug. Evidence protocol → `claude-config-validation`; sustained shortfall on cheaper tiers → `claude-config-model-uplift`; must-be-guaranteed rules → hooks/permissions (layer split: `claude-config-architecture`) |
| i | Edits land in the wrong place / `~/.claude` content stale | On a link-mode install: a symlink/junction was replaced by a real file/dir, splitting the copies. On a copy-mode install (`install.ps1 -Mode Copy`): real files are EXPECTED — "stale" just means a refresh is due | T1 — empty `LinkType` = real file; then ask which install mode this machine uses | Link-mode: relink via `install.ps1`. Copy-mode: `git pull` + `install.ps1 -Mode Copy` (runbook: `claude-config-distribution`) |
| j | File garbled or other tools misread it | Written by PS 5.1 `Out-File`/`Set-Content` without `-Encoding utf8` → UTF-16 (incident I2) | T5 | Rewrite with `-Encoding utf8` (standing rule: CLAUDE.md → Environment Facts) |

## 2. Discriminating tests

T1–T6 were executed on this machine 2026-07-08; outputs shown are real. All are read-only.

**T1 — link health** (PowerShell):

```powershell
Get-Item "$HOME\.claude\skills", "$HOME\.claude\CLAUDE.md", "$HOME\.claude\settings.json" | Select-Object Name, LinkType, Target | Format-List
```

Healthy on a link-mode install: `skills` shows `LinkType : Junction`, `Target : {<clone>\skills}`; each file shows `LinkType : SymbolicLink` with its `<clone>\...` target. An empty `LinkType` = real file: broken on link-mode (row i), expected on a copy-mode install (`install.ps1 -Mode Copy`, 2026-07-10).

**T2 — folder/frontmatter name match** (PowerShell):

```powershell
Select-String '^name:' "$HOME\.claude\skills\<name>\SKILL.md"
```

Healthy: prints `name: <name>` where `<name>` equals the folder name exactly. Example real output: `...\skills\root-cause\SKILL.md:2:name: root-cause`.

**T3 — settings.json parses** (PowerShell):

```powershell
Get-Content "$HOME\.claude\settings.json" -Raw | ConvertFrom-Json | Out-Null; "settings.json: valid JSON"
```

Healthy: prints `settings.json: valid JSON`. A syntax error throws with the offending position instead.

**T4 — zip entry paths use forward slashes** (PowerShell):

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem; $z = [System.IO.Compression.ZipFile]::OpenRead("$HOME\.claude\dist\<name>.zip"); $z.Entries.FullName; $z.Dispose()
```

Healthy: every entry starts with `<name>/` and uses `/`, e.g. real output for root-cause.zip: `root-cause/SKILL.md`. Backslash entries = the zip was not built by `sync.ps1` (incident I1).

**T5 — encoding BOM check** (PowerShell):

```powershell
[System.IO.File]::ReadAllBytes("<absolute-path>")[0..2] -join ','
```

`255,254,...` = UTF-16 LE — broken for cross-tool use (row j). `239,187,191` = UTF-8 BOM — fine. Plain ASCII bytes (no BOM) — fine. Verified both ways with `Out-File` defaults vs `-Encoding utf8`.

**T6 — run the SessionStart hook standalone** (bash): copy the `command` string from `hooks.SessionStart` in `<clone>\settings.json` and run it in Git Bash inside the target repo. Verified behavior: in a git repo with no CLAUDE.md it prints the JSON `{"systemMessage":"This repo has no CLAUDE.md ..."}`; in a non-repo or a repo that has CLAUDE.md it prints nothing and exits 0 — **silence there is healthy**.

**T7 — in-session and CLI probes** (verified against official docs 2026-07-08, not runnable inside a sandboxed subagent): `/context` (everything loaded, by category), `/skills`, `/memory`, `/hooks`, `/doctor`, `/status`, `/permissions`; `claude --debug hooks` (live hook evaluation log); `claude --safe-mode` (all customizations off — if the problem disappears, the cause is in this config; if it persists, look outside it). Source: https://code.claude.com/docs/en/debug-your-config

## 3. Incident chronicle — settled battles, do not re-fight

| # | Symptom | Root cause | Evidence | Status |
| --- | --- | --- | --- | --- |
| I1 | Uploaded zips unpacked wrong on Linux/claude.ai | PS 5.1 `Compress-Archive` writes backslash zip entries that Linux extractors misread (full mechanism: `claude-config-distribution` §3) | `sync.ps1` header comment | Settled — `sync.ps1` zips via `System.IO.Compression`, forcing forward slashes. Never build upload zips with `Compress-Archive` |
| I2 | Files written by PowerShell unreadable/garbled for other tools | PS 5.1 `Out-File`/`Set-Content` default to UTF-16 | CLAUDE.md → Environment Facts | Settled — always pass `-Encoding utf8` |
| I3 | Skills/config absent in web sessions | User-level `~/.claude` never carries over to Claude Code web | README → "Web availability (verified)" | Settled — upload dist zips (primary) or per-repo copies; routes in `claude-config-distribution` |

## 4. Escalation

- Symptom not in the table, or the test contradicts the expected cause → apply the generic four-phase method: `root-cause` (reproduce, bisect, explain, fix).
- Config proven correct but the model misbehaves → `claude-config-validation` for the evidence and trigger-test protocol; a sustained adherence shortfall on cheaper tiers → the `claude-config-model-uplift` campaign.

## When NOT to use this skill

- Bug in application code, tests, or any other repo → `root-cause`
- Proactive structural health scan when nothing is visibly broken → `claude-config-diagnostics`
- How the platform works (loading order, settings precedence, hook events, upload limits) → `claude-config-platform-reference`
- Rebuilding symlinks/junction, sync/zip/upload mechanics → `claude-config-distribution`
- Shipping the fix once found → `claude-config-change-control`

## Provenance and maintenance

Written 2026-07-08. T1–T6 executed on this machine that day; T7 verified against https://code.claude.com/docs/en/debug-your-config and https://code.claude.com/docs/en/cli-reference (fetched 2026-07-08); the row-f fact that hook edits are picked up automatically by the file watcher comes from https://code.claude.com/docs/en/hooks. Re-verify before trusting:

- Link targets and junction: run T1.
- Zip entry format: run T4 against any `~/.claude\dist\*.zip`.
- Hook command text: read `hooks.SessionStart` in `<clone>\settings.json`.
- README claims (web availability; new-session pickup of skill edits): re-read the "Editing a skill" and "Web availability (verified)" sections of `<clone>\README.md`.
- In-session commands and CLI flags (`/doctor`, `/status`, `/skills`, `/hooks`, `/memory`, `/context`, `--debug`, `--safe-mode`): re-fetch https://code.claude.com/docs/en/debug-your-config — these are platform-owned and drift; the loading/precedence facts behind rows e and g are owned by `claude-config-platform-reference`.
