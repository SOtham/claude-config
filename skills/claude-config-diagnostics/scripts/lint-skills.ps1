# lint-skills.ps1 - READ-ONLY structural linter for every skills\<dir>\SKILL.md.
#
# Per skill folder: SKILL.md exists; frontmatter (the YAML block between two
# '---' lines at the top of the file) parses; 'name:' equals the folder name;
# 'description:' is present, non-empty, and <=200 characters (claude.ai upload
# limit); SKILL.md over 160 lines is a warning, not a failure. Also detects
# duplicate frontmatter names across folders.
#
# Robust to half-written skills (empty files, missing/unclosed frontmatter):
# each such state is a reported finding, never a crash.
#
# READ-ONLY GUARANTEE: zero writes anywhere; output to stdout only.
# Exit codes: 0 = all skills pass (warnings allowed), 1 = at least one FAIL.
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

Write-Output ("lint-skills.ps1 - linting {0}" -f $skillsDir)
Write-Output ""

$seenNames = @{}   # frontmatter name -> array of folder names claiming it
$folders = @(Get-ChildItem -LiteralPath $skillsDir -Directory | Sort-Object Name)
if ($folders.Count -eq 0) {
    Report 'FAIL' ("no skill folders found under {0}" -f $skillsDir)
}

foreach ($folder in $folders) {
    $fname = $folder.Name
    $skillMd = Join-Path $folder.FullName 'SKILL.md'

    if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
        Report 'FAIL' ("{0}: SKILL.md missing" -f $fname)
        continue
    }

    $lines = @()
    try {
        $lines = @(Get-Content -LiteralPath $skillMd -ErrorAction Stop)
    } catch {
        Report 'FAIL' ("{0}: SKILL.md unreadable ({1})" -f $fname, $_.Exception.Message)
        continue
    }
    if ($lines.Count -eq 0) {
        Report 'FAIL' ("{0}: SKILL.md is empty (half-written?)" -f $fname)
        continue
    }

    # Frontmatter: first line must be ---, then a closing --- further down.
    if ($lines[0].Trim() -ne '---') {
        Report 'FAIL' ("{0}: no frontmatter (line 1 is not '---')" -f $fname)
        continue
    }
    $close = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $close = $i; break }
    }
    if ($close -lt 0) {
        Report 'FAIL' ("{0}: frontmatter never closed (no second '---'; half-written?)" -f $fname)
        continue
    }

    $fmLines = @()
    if ($close -gt 1) { $fmLines = $lines[1..($close - 1)] }
    $name = $null
    $desc = $null
    foreach ($l in $fmLines) {
        if ($l -match '^name:\s*(.*)$') { $name = $Matches[1].Trim() }
        elseif ($l -match '^description:\s*(.*)$') { $desc = $Matches[1].Trim() }
    }

    $ok = $true
    if ($null -eq $name -or $name -eq '') {
        Report 'FAIL' ("{0}: frontmatter has no 'name:' key" -f $fname)
        $ok = $false
    } elseif ($name -cne $fname) {
        Report 'FAIL' ("{0}: frontmatter name '{1}' does not equal folder name" -f $fname, $name)
        $ok = $false
    }
    if ($name) {
        if ($seenNames.ContainsKey($name)) {
            $seenNames[$name] = $seenNames[$name] + @($fname)
        } else {
            $seenNames[$name] = @($fname)
        }
    }

    if ($null -eq $desc -or $desc -eq '') {
        Report 'FAIL' ("{0}: frontmatter has no non-empty 'description:'" -f $fname)
        $ok = $false
    } elseif ($desc.Length -gt 200) {
        Report 'FAIL' ("{0}: description is {1} chars (claude.ai limit is 200)" -f $fname, $desc.Length)
        $ok = $false
    }

    if ($lines.Count -gt 160) {
        Report 'WARN' ("{0}: SKILL.md is {1} lines (>160 house guidance - move detail to references/ or scripts/)" -f $fname, $lines.Count)
    }

    if ($ok) {
        Report 'PASS' ("{0} ({1} lines, description {2} chars)" -f $fname, $lines.Count, $desc.Length)
    }
}

# --- Duplicate frontmatter names across folders ---------------------------------
foreach ($key in $seenNames.Keys) {
    $claimants = @($seenNames[$key])
    if ($claimants.Count -gt 1) {
        Report 'FAIL' ("duplicate skill name '{0}' claimed by folders: {1}" -f $key, ($claimants -join ', '))
    }
}

Write-Output ""
Write-Output ("lint summary: {0} folder(s) checked, {1} FAIL, {2} WARN" -f $folders.Count, $script:fails, $script:warns)
if ($script:fails -gt 0) { exit 1 } else { exit 0 }
