# install.ps1 - Link this claude-config clone into ~/.claude (idempotent).
#
# Makes Claude Code read this clone as the user-level config by creating
# 5 file symlinks + the skills junction in ~/.claude. Safe to re-run:
#   correct links   -> left alone ([OK])
#   wrong-target    -> repointed ([FIX])
#   real files/dirs -> moved to ~/.claude/backup-<stamp>/ first ([SAVE])
# Nothing inside the clone is ever modified.
#
# Run:  powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Notes
# - The skills junction needs no privileges. File symlinks need Windows
#   Developer Mode or an elevated shell; failing both, the file is COPIED
#   as a degraded fallback (edits stop propagating - enable Developer Mode
#   and re-run to upgrade copies back to links).
# - settings.json ships this owner's preferences (model, effortLevel) -
#   review it after install. Upload route for claude.ai/web: README.md.
# - Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$dst = Join-Path $HOME '.claude'
$backup = Join-Path $dst ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $dst | Out-Null

function New-FileLink([string]$target, [string]$link) {
    try {
        New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
        return 'SymbolicLink'
    } catch {
        cmd /c mklink "$link" "$target" 1>$null 2>$null
        if ($LASTEXITCODE -eq 0) { return 'SymbolicLink (via mklink)' }
        Copy-Item $target $link
        return 'COPY (degraded: enable Developer Mode and re-run)'
    }
}

$entries = @(
    @{ Name = 'CLAUDE.md';         Kind = 'file' },
    @{ Name = 'settings.json';     Kind = 'file' },
    @{ Name = 'sync.ps1';          Kind = 'file' },
    @{ Name = 'CLAUDE-SNIPPET.md'; Kind = 'file' },
    @{ Name = 'README.md';         Kind = 'file' },
    @{ Name = 'skills';            Kind = 'dir'  }
)

$failed = $false
foreach ($e in $entries) {
    $target = Join-Path $src $e.Name
    $link   = Join-Path $dst $e.Name
    if (-not (Test-Path $target)) { Write-Output ("[FAIL] missing in clone: " + $target); $failed = $true; continue }

    $existing = $null
    try { $existing = Get-Item $link -Force -ErrorAction Stop } catch {}

    if ($existing -and $existing.LinkType) {
        $t = @($existing.Target)[0]
        if ($t -eq $target) { Write-Output ("[OK]   " + $e.Name + " already linked"); continue }
        Write-Output ("[FIX]  " + $e.Name + ": linked to '" + $t + "', repointing to this clone")
        if ($e.Kind -eq 'dir') { cmd /c rmdir "$link" 1>$null 2>$null }   # rmdir removes the junction, never its target's contents
        else { Remove-Item $link -Force -Confirm:$false }
    } elseif ($existing) {
        New-Item -ItemType Directory -Force $backup | Out-Null
        Write-Output ("[SAVE] " + $e.Name + " is a real " + $e.Kind + "; moved to " + $backup)
        Move-Item $link (Join-Path $backup $e.Name)
    }

    if ($e.Kind -eq 'dir') {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        Write-Output ("[NEW]  " + $e.Name + " -> Junction")
    } else {
        Write-Output ("[NEW]  " + $e.Name + " -> " + (New-FileLink $target $link))
    }
}

if ($src -ne 'C:\Dev\claude-config') {
    Write-Output ""
    Write-Output ("note: this clone lives at '" + $src + "'. Library docs cite C:\Dev\claude-config as the canonical path; all scripts derive paths from the clone location, but update the 'Personal skills' line in CLAUDE.md if you keep this location.")
}

$doctor = Join-Path $src 'skills\claude-config-diagnostics\scripts\doctor.ps1'
if (Test-Path $doctor) {
    Write-Output ""
    & powershell -ExecutionPolicy Bypass -File $doctor
    if ($LASTEXITCODE -ne 0) { $failed = $true }
}

if ($failed) { exit 1 } else { exit 0 }
