# One-shot test: does claude.ai reject or truncate a >200-char skill description?

**Status: not yet run** (as of 2026-07-10). Needs the claude.ai web UI, ~3 minutes. Settles the one undocumented fact in `SKILL.md` §5: the docs confirm the 200-char limit but say nothing about what happens at 201 — hard reject (upload fails) or silent truncation (accepted, description cut). Claude Code truncates its *own* `/skills` listing at 250 (GitHub anthropics/claude-code #40121), so truncation is plausible.

## Build the probe zip (PowerShell 5.1 — tested 2026-07-10)

Uses `System.IO.Compression` directly for forward-slash entry paths; `Compress-Archive` would write backslashes and break extraction (`claude-config-distribution` §3). The description below is exactly **201** characters.

```powershell
$src = "$env:TEMP\zzz-limit-probe"; New-Item -ItemType Directory -Force $src | Out-Null
@'
---
name: zzz-limit-probe
description: Boundary-probe skill for the claude.ai upload limit test. Use to check whether a description of exactly two hundred and one characters is accepted verbatim, truncated, or rejected on upload to the page
---
# Probe
Throwaway skill for the upload boundary test. Delete after the test.
'@ | Out-File "$src\SKILL.md" -Encoding utf8
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = "$env:TEMP\zzz-limit-probe.zip"; if (Test-Path $zip) { Remove-Item $zip -Force }
$a = [System.IO.Compression.ZipFile]::Open($zip,'Create')
[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($a, "$src\SKILL.md", 'zzz-limit-probe/SKILL.md') | Out-Null
$a.Dispose(); Write-Output "ready: $zip"
```

The probe lives in `%TEMP%`, never in this library — it must not be synced or kept.

## Run

1. claude.ai → **Settings > Capabilities** (label drifts; help center says "Customize > Skills") → upload `%TEMP%\zzz-limit-probe.zip`.
2. Record which of these happened:

| Outcome | Meaning | Follow-up (all via `claude-config-change-control`) |
| --- | --- | --- |
| Rejected with a length error | Hard reject — the library's ≤200 rule is exactly right | Update `SKILL.md` §5 to "rejected (verified <date>)"; done |
| Accepted, description shown cut to 200 | Silent truncation | Update §5: risk is silent trigger-word loss, not failure; keep ≤200 rule |
| Accepted, full 201 shown | Limit not enforced at upload | Update §5; consider relaxing `lint-skills.ps1` hard-fail to WARN and change-control non-negotiable (d) |

3. Control: rebuild with a 200-char description (delete one trailing character) and confirm it uploads clean — isolates the boundary.
4. Delete the probe skill from claude.ai and from `%TEMP%`.
5. Record the outcome: dated line in `SKILL.md` §5 replacing "undocumented", plus a dated line in `claude-config-research/references/experiment-log.md` if you want it in the program record.

## Provenance

Written 2026-07-10. Builder snippet executed and verified that day (entry path `zzz-limit-probe/SKILL.md`, description length 201). Sources: https://claude.com/docs/skills/how-to (200-char warning, fetched 2026-07-09 and 2026-07-10); https://github.com/anthropics/claude-code/issues/40121 (250-char listing truncation).
