# lint-skills.ps1 - READ-ONLY structural linter for every skills\<dir>\SKILL.md.
#
# Per skill folder: SKILL.md exists; frontmatter (the YAML block between two
# '---' lines at the top of the file) parses; 'name:' equals the folder name;
# 'description:' is present, non-empty, and <=200 characters (claude.ai upload
# limit); SKILL.md over 160 lines is a warning, not a failure. Also detects
# duplicate frontmatter names across folders.
#
# Body checks (added 2026-07-18): scripts/ or references/ files named in the
# body must exist in the skill folder (FAIL); description should carry a
# 'Use when' clause (WARN); backticked kebab-case tokens that look like skill
# references must resolve to an existing skills\<name> folder or the allowlist
# (WARN - catches rename/retire rot).
#
# -SkillsDir <path>: lint that directory instead of the repo's skills\ (used by
# tests\selftest-lint.tests.sh to point the linter at a synthetic fixture tree).
#
# Robust to half-written skills (empty files, missing/unclosed frontmatter):
# each such state is a reported finding, never a crash.
#
# READ-ONLY GUARANTEE: zero writes anywhere; output to stdout only.
# Exit codes: 0 = all skills pass (warnings allowed), 1 = at least one FAIL.
# Windows PowerShell 5.1 compatible. Works from any CWD.

param(
    [string]$SkillsDir
)

$ErrorActionPreference = 'Stop'

$script:fails = 0
$script:warns = 0
function Report {
    param([string]$Status, [string]$Message)
    if ($Status -eq 'FAIL') { $script:fails = $script:fails + 1 }
    if ($Status -eq 'WARN') { $script:warns = $script:warns + 1 }
    Write-Output ("[{0}] {1}" -f $Status, $Message)
}

# --- Derive skills dir from this script's own location (unless -SkillsDir given) ---
# NOTE: PowerShell variables are case-insensitive, so $skillsDir IS the $SkillsDir param.
if (-not $SkillsDir) {
    $skillDir  = Split-Path -Parent $PSScriptRoot
    $skillsDir = Split-Path -Parent $skillDir
    try {
        $skillsItem = Get-Item -LiteralPath $skillsDir -Force
        if ($skillsItem.LinkType) {
            $target = @($skillsItem.Target) | Select-Object -First 1
            if ($target) { $skillsDir = $target }
        }
    } catch { }
}

# Backticked kebab-case tokens that legitimately are NOT skill references.
# Tune here when the sibling-reference WARN flags a false positive.
# Seeded 2026-07-18 from the first full run: platform frontmatter field names,
# model ids, a bundled-skill example, and test-gate's exemption categories.
$refAllowlist = @(
    'allowed-tools', 'argument-hint', 'disable-model-invocation',
    'disallowed-tools', 'user-invocable',
    'claude-haiku-4-5', 'usage-credits',
    'config-only', 'inline-tests', 'no-infra', 'ui-glue'
)

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

    # --- Body checks (2026-07-18) ---------------------------------------------
    $body = @()
    if ($close + 1 -le $lines.Count - 1) { $body = $lines[($close + 1)..($lines.Count - 1)] }
    $bodyText = ($body -join "`n")

    # (a) FAIL: scripts/ or references/ files named in the body must exist in the
    #     folder. Lookbehind excludes longer paths (<other-skill>/scripts/x.sh).
    $fileRefs = [regex]::Matches($bodyText, '(?<![\w/.-])(scripts|references)/[A-Za-z0-9._-]+') |
        ForEach-Object { $_.Value } | Sort-Object -Unique
    foreach ($ref in $fileRefs) {
        $refPath = Join-Path $folder.FullName ($ref -replace '/', '\')
        if (-not (Test-Path -LiteralPath $refPath -PathType Leaf)) {
            Report 'FAIL' ("{0}: body references {1} but no such file exists in the skill folder" -f $fname, $ref)
            $ok = $false
        }
    }

    # (b) WARN: the description recipe ends with a trigger clause ('Use when <triggers>';
    #     house variants observed 2026-07-18: 'Use for/before', 'Run before/after').
    #     A missing clause usually means weak auto-load triggers.
    if ($desc -and $desc -notmatch '(Use|Run) (when|for|before|after)') {
        Report 'WARN' ("{0}: description has no trigger clause ('Use when ...' - recipe: claude-config-skill-authoring)" -f $fname)
    }

    # (c) WARN: backticked kebab-case token that resolves to no skills\<name>
    #     folder and is not allowlisted - likely a renamed/retired skill reference.
    $tickTokens = [regex]::Matches($bodyText, '`([a-z0-9]+(?:-[a-z0-9]+)+)`') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($tok in $tickTokens) {
        if ($tok -eq $fname) { continue }
        if ($refAllowlist -contains $tok) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $skillsDir $tok) -PathType Container)) {
            Report 'WARN' ("{0}: backticked reference '{1}' matches no skills folder (renamed/retired skill, or add to the lint allowlist)" -f $fname, $tok)
        }
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
