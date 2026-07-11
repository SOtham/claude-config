# install.ps1 - Put this claude-config clone into ~/.claude (idempotent).
#
# Two modes:
#   -Mode Link (default)  5 file symlinks + skills junction -> the clone stays
#                         the single edit surface; `git pull` updates everything.
#   -Mode Copy            real copies, no links/reparse points at all -> for
#                         machines where links are unwanted. Trade-off: edits do
#                         NOT propagate; refresh = `git pull` + re-run this. The
#                         doctor reports copy-mode entries as WARN, not FAIL.
#
# Idempotent and safe to re-run in either mode:
#   correct link / identical copy  -> left alone            [OK]
#   wrong-target or wrong-kind     -> replaced              [FIX]
#   differing real file            -> backed up, replaced   [SAVE]
#   skills dir in copy mode        -> merge-overwritten     [SYNC]
# Real files are only ever moved to ~/.claude/backup-<stamp>/, never deleted.
# Nothing inside the clone is ever modified.
#
# Run:  powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Mode Copy]
#
# Notes
# - Link mode: the skills junction needs no privileges; file symlinks need
#   Developer Mode or an elevated shell, else that file falls back to a COPY.
# - Copy mode: upstream skill DELETIONS do not propagate via the merge-copy;
#   remove obsolete folders from ~/.claude/skills manually (check-dist.ps1
#   flags their orphan zips).
# - settings.json ships this owner's preferences (model, effortLevel) -
#   review after install. claude.ai/web upload route: README.md.
# - -Dest overrides the target directory (testing only).
# - Windows PowerShell 5.1 compatible.

param(
    [ValidateSet('Link','Copy')] [string]$Mode = 'Link',
    [string]$Dest = (Join-Path $HOME '.claude')
)
$ErrorActionPreference = 'Stop'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$backup = Join-Path $Dest ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $Dest | Out-Null
Write-Output ("install.ps1 - mode: {0}   clone: {1}   dest: {2}" -f $Mode, $src, $Dest)

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

function Remove-LinkOnly([object]$item, [string]$kind) {
    # Junctions/dir-links via rmdir (never recurses into the target); file links via Remove-Item.
    if ($kind -eq 'dir') { cmd /c rmdir "$($item.FullName)" 1>$null 2>$null }
    else { Remove-Item $item.FullName -Force -Confirm:$false }
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
    $link   = Join-Path $Dest $e.Name
    if (-not (Test-Path $target)) { Write-Output ("[FAIL] missing in clone: " + $target); $failed = $true; continue }

    $existing = $null
    try { $existing = Get-Item $link -Force -ErrorAction Stop } catch {}

    if ($Mode -eq 'Link') {
        if ($existing -and $existing.LinkType) {
            $t = @($existing.Target)[0]
            if ($t -eq $target) { Write-Output ("[OK]   " + $e.Name + " already linked"); continue }
            Write-Output ("[FIX]  " + $e.Name + ": linked to '" + $t + "', repointing to this clone")
            Remove-LinkOnly $existing $e.Kind
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
    } else {  # Copy mode
        if ($existing -and $existing.LinkType) {
            Write-Output ("[FIX]  " + $e.Name + ": was a link, replacing with a copy")
            Remove-LinkOnly $existing $e.Kind
            $existing = $null
        }
        if ($e.Kind -eq 'dir') {
            if (Test-Path $link) {
                Copy-Item (Join-Path $target '*') $link -Recurse -Force
                Write-Output ("[SYNC] " + $e.Name + " merge-copied (upstream deletions do not propagate)")
            } else {
                Copy-Item $target $link -Recurse
                Write-Output ("[NEW]  " + $e.Name + " -> copied")
            }
        } else {
            if ($existing) {
                $same = (Get-FileHash $target).Hash -eq (Get-FileHash $link).Hash
                if ($same) { Write-Output ("[OK]   " + $e.Name + " copy identical"); continue }
                New-Item -ItemType Directory -Force $backup | Out-Null
                Copy-Item $link (Join-Path $backup $e.Name)
                Write-Output ("[SAVE] " + $e.Name + " differed; previous version backed up to " + $backup)
            } else {
                Write-Output ("[NEW]  " + $e.Name + " -> copied")
            }
            Copy-Item $target $link -Force
        }
    }
}

Write-Output ""
Write-Output ("note: <clone> in the library's docs and skills means this clone root: " + $src)

$doctor = Join-Path $src 'skills\claude-config-diagnostics\scripts\doctor.ps1'
if ((Test-Path $doctor) -and ($Dest -eq (Join-Path $HOME '.claude'))) {
    Write-Output ""
    & powershell -ExecutionPolicy Bypass -File $doctor
    if ($LASTEXITCODE -ne 0) { $failed = $true }
}

if ($failed) { exit 1 } else { exit 0 }
