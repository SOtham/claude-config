---
name: claude-config-distribution
description: Rebuild and distribute this config - ~/.claude junction/symlink runbook, sync.ps1 zip build, claude.ai upload, per-repo copies. Use when setting up a new machine or shipping skill changes.
---

# Claude-Config Distribution

How to recreate this setup from nothing and operate its delivery routes. The canonical source is `C:\Dev\claude-config\`; everything else — `~/.claude`, the upload zips, per-repo copies — is a projection of it. Distribution is what puts the library's discipline in front of every session, including cheaper-tier ones on the web; a stale projection silently runs old rules. This skill owns mechanics only: *why* the design looks like this is `claude-config-architecture`; whether a change may ship is `claude-config-change-control`.

Terms: a **symbolic link (symlink)** is a filesystem pointer to another file or directory; a **junction** is an NTFS directory-only pointer that needs no special privilege to create; **dist/** is the folder of generated skill zips.

## 1. The three delivery surfaces

| Surface | Mechanism | Update procedure |
| --- | --- | --- |
| Local Claude Code (this machine) | `~/.claude` symlinks to the repo's files + a `skills` junction | Edit canonical files; new sessions pick changes up automatically |
| claude.ai + Claude Code web | Manual upload of `~/.claude\dist\<name>.zip` | `sync.ps1` (Section 3) → re-upload changed zips (Section 4) |
| Other repos / teammates | Paste `CLAUDE-SNIPPET.md` into the repo's `CLAUDE.md`; copy needed `skills/<name>/` folders into the repo's `.claude/skills/` | Follow the `repo-setup` skill — the checklist lives there, not here |

## 2. Rebuild from scratch (new machine)

**Fast path (added 2026-07-10):** `install.ps1` at the repo root automates steps 2–6 below idempotently — correct links left alone, wrong ones repointed, real files backed up to `~/.claude\backup-<stamp>\` — and finishes with the doctor health check. Tested: no-op path on a healthy install (6× OK, doctor HEALTHY); the fresh-machine path reuses the commands below but has not yet run end-to-end on a second machine. The manual steps remain authoritative for debugging and partial repairs.

All commands **PowerShell**, unelevated, tested 2026-07-08 unless labeled otherwise.

1. Clone the canonical source (git repo with private remote since 2026-07-10): `git clone https://github.com/SOtham/claude-config.git C:\Dev\claude-config` — needs an authenticated `gh`/git; fallback: restore from backup or copy from the old machine. Note: the remote holds committed state only.
2. Ensure the target directory exists:
   ```powershell
   New-Item -ItemType Directory -Force "$HOME\.claude" | Out-Null
   ```
3. Create the `skills` junction — works without admin (tested):
   ```powershell
   New-Item -ItemType Junction -Path "$HOME\.claude\skills" -Target "C:\Dev\claude-config\skills"
   ```
4. Create the five file symlinks. Privilege facts, tested in this session (unelevated, Developer Mode ON):
   - `New-Item -ItemType SymbolicLink` **fails unelevated even with Developer Mode enabled** — exact error: `Administrator privilege required for this operation.` (PowerShell 5.1 never passes the unprivileged-create flag.)
   - `cmd /c mklink` **succeeds unelevated when Developer Mode is on** (tested). Use it:
   ```powershell
   'CLAUDE.md','settings.json','sync.ps1','CLAUDE-SNIPPET.md','README.md' | ForEach-Object {
     cmd /c mklink "$HOME\.claude\$_" "C:\Dev\claude-config\$_"
   }
   ```
   - Check Developer Mode first (tested; value `1` = on): `(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock').AllowDevelopmentWithoutDevLicense`. If it is off and you cannot enable it, run the `New-Item -ItemType SymbolicLink` commands from an elevated PowerShell instead (documented Windows behavior — Unverified here; this session is unelevated).
5. Verify the links (tested; this is also today's actual state):
   ```powershell
   Get-ChildItem "$HOME\.claude" -Force | Select-Object Name, LinkType, Target
   ```
   Expected: `skills` = **Junction**; `CLAUDE.md`, `settings.json`, `sync.ps1`, `CLAUDE-SNIPPET.md`, `README.md` = **SymbolicLink** (verified 2026-07-08). `dist` is a real directory, created by `sync.ps1`, never linked.
6. Build the upload zips — invoke via the `~/.claude` path exactly as written (see the Section 3 note on `$root`):
   ```powershell
   powershell -ExecutionPolicy Bypass -File "$HOME\.claude\sync.ps1"
   ```
7. Upload the zips per Section 4.
8. Sanity check: start a new Claude Code session in any repo — skills should be invocable as `/<name>`; `/memory` confirms the global `CLAUDE.md` loads (per the `repo-setup` skill's verify step).

Why the split link types: junctions cover directories without privilege; files need real symlinks, which is where the Developer-Mode/mklink dance comes from.

## 3. sync.ps1 anatomy

Source: `C:\Dev\claude-config\sync.ps1` (40 lines; read it before changing anything). Step by step:

1. `$root = Split-Path -Parent $MyInvocation.MyCommand.Path` — the directory the script was *invoked from*. PowerShell 5.1 does **not** resolve symlinks here (tested with a probe script behind a symlink: it reports the link path). Invoked as `$HOME\.claude\sync.ps1`, `$root` is `~/.claude`, so `$skills` reads through the junction and zips land in `~/.claude\dist\`. Invoking `C:\Dev\claude-config\sync.ps1` directly would create a *second* dist at `C:\Dev\claude-config\dist` (does not exist today — verified) while the real one goes stale. Always use the documented invocation.
2. Creates `dist\` if missing.
3. For each directory under `skills\`: deletes any existing `dist\<name>.zip`, then builds a fresh zip via `System.IO.Compression.ZipFile`, adding every file recursively with entry path `<name>/<relative-path>` — skill folder at the zip root, **forward slashes** forced by `-replace '\\', '/'`.
4. Prints `packaged <name> -> dist\<name>.zip` per skill, then an upload reminder.

**The incident behind it** (source: the script's header comment): PowerShell 5.1's `Compress-Archive` writes *backslash* entry paths inside the zip. Linux extractors — which is what claude.ai runs — treat `\` as a literal filename character, so the skill arrives as one file named `name\SKILL.md` instead of a folder, and the upload is useless. That is why the script calls `System.IO.Compression` directly. Never "simplify" it back to `Compress-Archive`.

What it does **not** do: it never deletes zips for skill folders that no longer exist (verified from source — the only `Remove-Item` targets the zip it is about to rebuild). See the traps table.

## 4. claude.ai upload procedure

1. Run `sync.ps1` (Section 2 step 6 invocation, verbatim from `CLAUDE.md`/`README.md`).
2. Go to claude.ai → **Settings → Capabilities → Skills**; upload (or replace) each changed `~/.claude\dist\<name>.zip`.
3. Uploaded skills also load into Claude Code web sessions automatically (README) — this is the primary web route.

Constraints (`description` ≤200 chars, naming coupling, etc.): one line each in `claude-config-platform-reference` — check there before authoring. The upload is **manual**, so claude.ai silently lags `skills/` until someone re-uploads; detect staleness with the dist checks in `claude-config-diagnostics`. Live example, re-verified 2026-07-09: `dist\` held 15 zips while `skills\` had 25 folders — the 10 new meta-layer skills existed locally but not on the web.

## 5. Environment traps (distribution-relevant)

| Trap | Symptom | Avoidance |
| --- | --- | --- |
| `Out-File`/`Set-Content` default to UTF-16 in PS 5.1 | Edited SKILL.md shows BOM/NUL garbage to other tools; zip content garbled | Always pass `-Encoding utf8` |
| No `&&` chaining in PS 5.1 (the OR chain operator is missing too) | `The token '&&' is not a valid statement separator in this version.` (verified verbatim) | Use `;`, `if ($?) { }`, or the Bash tool |
| `Compress-Archive` backslash entries | Skill extracts on Linux as a single file with `\` in its name; upload broken | Keep sync.ps1 on `System.IO.Compression` (Section 3) |
| Editing via `~/.claude` link vs canonical path | None — it is the same file (verified: identical content hash via both paths) | Either works; canonical home is `C:\Dev\claude-config` |
| Renaming/deleting a skill folder | Stale `dist\<old-name>.zip` survives every sync (verified: no orphan cleanup in source), and the old claude.ai upload lingers too | Delete the orphan zip yourself and remove the old skill on claude.ai |
| Running sync.ps1 by its canonical path | Zips appear in a new `C:\Dev\claude-config\dist\`; `~/.claude\dist\` and your uploads go stale | Invoke via `"$HOME\.claude\sync.ps1"` only (Section 3, step 1) |

## 6. Future route — plugin + marketplace (candidate)

`open/candidate — not built.` README lists a fourth route "later, if sharing is wanted": convert the skills into a Claude Code plugin published via a marketplace repo on GitHub, declared in each repo's `.claude/settings.json`. Nothing exists yet — no plugin manifest, no repo, no procedure — so do not present it as available; if it gets built, the decision record belongs in `claude-config-architecture` and the mechanics move here.

## When NOT to use this skill

- Platform facts — upload limits, frontmatter fields, skills discovery, settings precedence → `claude-config-platform-reference`
- Whether a change is allowed, and the ship-it gate sequence → `claude-config-change-control`
- Something is broken (skill not loading, upload rejected, hook silent) → `claude-config-debugging`
- Health scripts and staleness detection tooling → `claude-config-diagnostics`
- Authoring or editing a skill's content → `claude-config-skill-authoring`
- Setting up another repo's Claude files → `repo-setup`

## Provenance and maintenance

Written 2026-07-08 against the live system (links inspected, creation commands tested unelevated in the session scratchpad); inventory re-verified 2026-07-09: 25 skill folders, 15 zips in dist. Counts drift — re-run the one-liners below rather than trusting the snapshot:

- Link types and targets (PowerShell): `Get-ChildItem "$HOME\.claude" -Force | Select-Object Name, LinkType, Target`
- Symlink privilege behavior: re-run `New-Item -ItemType SymbolicLink` and `cmd /c mklink` on throwaway paths in a scratch directory — never against `~/.claude`
- Developer Mode state (PowerShell): `(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock').AllowDevelopmentWithoutDevLicense`
- sync.ps1 behavior, backslash incident, orphan handling: read `C:\Dev\claude-config\sync.ps1` (header + loop, 40 lines)
- Exact invocation string: `CLAUDE.md` Environment Facts bullet 2; `README.md` "Editing a skill"
- dist staleness (PowerShell): compare `Get-ChildItem "$HOME\.claude\dist"` against `Get-ChildItem "$HOME\.claude\skills" -Directory` (scripted version: `claude-config-diagnostics`)
- Upload UI path (claude.ai → Settings → Capabilities → Skills): README; UI locations move — re-check in the product if the path 404s
