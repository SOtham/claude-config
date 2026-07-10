# check-dist.ps1 - READ-ONLY staleness check for the claude.ai upload zips.
#
# sync.ps1 packages each skills\<name>\ folder into ~/.claude/dist/<name>.zip
# (dist/ sits next to sync.ps1's invoked path; the documented invocation is via
# the ~/.claude/sync.ps1 symlink, so dist/ lands in ~/.claude/dist).
# For every skill folder this script reports:
#   MISSING - no dist\<name>.zip           -> run sync.ps1, then upload
#   STALE   - a file in the skill folder is newer than its zip -> same
#   ORPHAN  - a zip in dist\ has no matching skill folder      -> investigate
# Also WARNs if a second dist\ exists inside the canonical repo (created when
# sync.ps1 is invoked via its repo path instead of the $HOME symlink).
# A freshly authored skill is EXPECTED to show MISSING until sync.ps1 runs.
#
# READ-ONLY GUARANTEE: zero writes anywhere; output to stdout only.
# Exit codes: 0 = every zip present and fresh, 1 = any missing/stale/orphaned.
# Windows PowerShell 5.1 compatible. Works from any CWD.

$ErrorActionPreference = 'Stop'

$script:fails = 0
$script:warns = 0
function Report {
    param([string]$Status, [string]$Message)
    if ($Status -eq 'FAIL') { $script:fails = $script:fails + 1 }
    if ($Status -eq 'WARN') { $script:warns = $script:warns + 1 }
    Write-Output ("[{0}] {1}" -f $Status, $Message)
}

# --- Derive skills dir from this script's own location -------------------------
$skillDir  = Split-Path -Parent $PSScriptRoot
$skillsDir = Split-Path -Parent $skillDir
try {
    $skillsItem = Get-Item -LiteralPath $skillsDir -Force
    if ($skillsItem.LinkType) {
        $target = @($skillsItem.Target) | Select-Object -First 1
        if ($target) { $skillsDir = $target }
    }
} catch { }

$repoRoot = Split-Path -Parent $skillsDir
$distDir = Join-Path $HOME '.claude\dist'

Write-Output ("check-dist.ps1 - skills: {0}" -f $skillsDir)
Write-Output ("                 dist:   {0}" -f $distDir)
Write-Output ""

# sync.ps1 derives dist\ from its own invoked path. Invoked via the canonical
# repo path (instead of the documented $HOME\.claude\sync.ps1 symlink) it
# creates a SECOND dist\ inside the repo that the upload workflow never sees.
$repoDist = Join-Path $repoRoot 'dist'
if (Test-Path -LiteralPath $repoDist -PathType Container) {
    Report 'WARN' ("second dist exists at {0} - sync.ps1 was invoked via its canonical repo path; use the documented HOME invocation and remove the repo copy (see claude-config-distribution)" -f $repoDist)
}

if (-not (Test-Path -LiteralPath $distDir -PathType Container)) {
    Report 'FAIL' ("dist directory missing: {0} - run sync.ps1 to create it" -f $distDir)
    Write-Output ""
    Write-Output "dist summary: 1 FAIL"
    exit 1
}

$folders = @(Get-ChildItem -LiteralPath $skillsDir -Directory | Sort-Object Name)
$staleCount = 0
$missingCount = 0

foreach ($folder in $folders) {
    $name = $folder.Name
    $zipPath = Join-Path $distDir ($name + '.zip')
    $files = @(Get-ChildItem -LiteralPath $folder.FullName -Recurse -File)

    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        $missingCount = $missingCount + 1
        Report 'FAIL' ("{0}: zip MISSING (expected for a brand-new skill) - run sync.ps1, then upload {0}.zip" -f $name)
        continue
    }
    if ($files.Count -eq 0) {
        Report 'WARN' ("{0}: skill folder contains no files (half-written?) but a zip exists" -f $name)
        continue
    }

    $zipTime = (Get-Item -LiteralPath $zipPath).LastWriteTime
    $newest = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($newest.LastWriteTime -gt $zipTime) {
        $staleCount = $staleCount + 1
        Report 'FAIL' ("{0}: zip STALE - {1} modified {2}, zip built {3} - run sync.ps1, then re-upload {0}.zip" -f `
            $name, $newest.Name, $newest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $zipTime.ToString('yyyy-MM-dd HH:mm:ss'))
    } else {
        Report 'PASS' ("{0}: zip up to date (built {1})" -f $name, $zipTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
}

# --- Orphan zips: in dist\ but no matching skill folder --------------------------
$folderNames = @($folders | ForEach-Object { $_.Name })
$zips = @(Get-ChildItem -LiteralPath $distDir -Filter '*.zip' -File | Sort-Object Name)
foreach ($zip in $zips) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($zip.Name)
    if (-not ($folderNames -contains $base)) {
        Report 'FAIL' ("orphan zip: dist\{0} has no skills\{1}\ folder - deleted or renamed skill? Remove the upload too if retired" -f $zip.Name, $base)
    }
}

Write-Output ""
Write-Output ("dist summary: {0} skill(s), {1} zip(s); {2} missing, {3} stale; {4} FAIL, {5} WARN" -f `
    $folders.Count, $zips.Count, $missingCount, $staleCount, $script:fails, $script:warns)
if ($script:fails -gt 0) {
    Write-Output "action: run sync.ps1 (see claude-config-distribution), then re-upload the named zips at claude.ai > Settings > Capabilities > Skills"
    exit 1
} else {
    Write-Output "result: dist/ in sync with skills/"
    exit 0
}
