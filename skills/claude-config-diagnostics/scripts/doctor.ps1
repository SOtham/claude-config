# doctor.ps1 - One-shot READ-ONLY structural health check for the claude-config system.
#
# Checks: (a) canonical repo has the expected top-level files, (b) every expected
# ~/.claude entry exists with the right link type (SymbolicLink for the five files,
# Junction for skills\) and its target points into the canonical repo, (c)
# settings.json parses and still carries the full secrets deny-rule baseline,
# (d) CLAUDE.md line count vs its ~120-line maintainer budget (warning only).
#
# READ-ONLY GUARANTEE: this script makes zero writes anywhere - no files created,
# modified, or deleted; output goes to stdout only.
#
# Exit codes: 0 = healthy (warnings allowed), 1 = at least one FAIL finding.
# Windows PowerShell 5.1 compatible. Works from any CWD (paths derive from
# $PSScriptRoot: scripts\ -> skill folder -> skills\ -> repo root; if invoked
# through the ~/.claude/skills junction, the junction target is resolved first).

$ErrorActionPreference = 'Stop'

$script:fails = 0
$script:warns = 0
function Report {
    param([string]$Status, [string]$Message)
    if ($Status -eq 'FAIL') { $script:fails = $script:fails + 1 }
    if ($Status -eq 'WARN') { $script:warns = $script:warns + 1 }
    Write-Output ("[{0}] {1}" -f $Status, $Message)
}

# --- Derive canonical repo root from this script's own location ---------------
$skillDir  = Split-Path -Parent $PSScriptRoot     # ...\skills\claude-config-diagnostics
$skillsDir = Split-Path -Parent $skillDir         # ...\skills
try {
    $skillsItem = Get-Item -LiteralPath $skillsDir -Force
    if ($skillsItem.LinkType) {
        $target = @($skillsItem.Target) | Select-Object -First 1
        if ($target) { $skillsDir = $target }     # resolve ~/.claude/skills junction
    }
} catch { }
$repoRoot = Split-Path -Parent $skillsDir

Write-Output ("doctor.ps1 - claude-config health check ({0})" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Output ("canonical repo root: {0}" -f $repoRoot)
Write-Output ""

# --- (a) Canonical repo: expected top-level entries ---------------------------
Write-Output "== Check A: canonical repo layout =="
if (-not (Test-Path -LiteralPath $repoRoot -PathType Container)) {
    Report 'FAIL' ("repo root not found: {0}" -f $repoRoot)
} else {
    $expectedFiles = @('CLAUDE.md', 'settings.json', 'sync.ps1', 'CLAUDE-SNIPPET.md', 'README.md')
    foreach ($f in $expectedFiles) {
        $p = Join-Path $repoRoot $f
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            Report 'PASS' ("repo file present: {0}" -f $f)
        } else {
            Report 'FAIL' ("repo file MISSING: {0}" -f $p)
        }
    }
    if (Test-Path -LiteralPath (Join-Path $repoRoot 'skills') -PathType Container) {
        Report 'PASS' "repo directory present: skills\"
    } else {
        Report 'FAIL' ("repo directory MISSING: {0}" -f (Join-Path $repoRoot 'skills'))
    }
}

# --- (b) ~/.claude link inventory ---------------------------------------------
# Healthy state (inspected 2026-07-08): the five files are SymbolicLink entries,
# skills is a Junction; every target points at the same-named entry in the repo.
Write-Output ""
Write-Output "== Check B: ~/.claude links =="
$claudeDir = Join-Path $HOME '.claude'
$expectedLinks = @(
    @{ Name = 'CLAUDE.md';         Type = 'SymbolicLink' },
    @{ Name = 'settings.json';     Type = 'SymbolicLink' },
    @{ Name = 'sync.ps1';          Type = 'SymbolicLink' },
    @{ Name = 'CLAUDE-SNIPPET.md'; Type = 'SymbolicLink' },
    @{ Name = 'README.md';         Type = 'SymbolicLink' },
    @{ Name = 'skills';            Type = 'Junction' }
)
foreach ($link in $expectedLinks) {
    $p = Join-Path $claudeDir $link.Name
    if (-not (Test-Path -LiteralPath $p)) {
        Report 'FAIL' ("~/.claude entry MISSING: {0}" -f $link.Name)
        continue
    }
    $item = Get-Item -LiteralPath $p -Force
    $actualTarget = @($item.Target) | Select-Object -First 1
    $expectedTarget = Join-Path $repoRoot $link.Name
    if (-not $item.LinkType) {
        # Real file/dir, not a link: legitimate on a copy-mode install (install.ps1 -Mode Copy),
        # where edits do NOT propagate from the clone - refresh by re-running install.ps1 -Mode Copy.
        # On a link-mode install this same state means a link was clobbered by a real file (triage:
        # claude-config-debugging row i). WARN either way - the doctor cannot tell the modes apart.
        Report 'WARN' ("~/.claude\{0} is a real {1}, not a link: copy-mode install (drift risk; refresh via install.ps1 -Mode Copy) OR a clobbered link (relink via install.ps1)" -f $link.Name, $(if ($link.Type -eq 'Junction') { 'directory' } else { 'file' }))
    } elseif ($item.LinkType -ne $link.Type) {
        Report 'FAIL' ("~/.claude\{0}: expected {1}, found {2}" -f $link.Name, $link.Type, $item.LinkType)
    } elseif (-not ($actualTarget -ieq $expectedTarget)) {
        Report 'FAIL' ("~/.claude\{0}: target '{1}' does not match canonical '{2}'" -f $link.Name, $actualTarget, $expectedTarget)
    } else {
        Report 'PASS' ("~/.claude\{0} is a {1} -> {2}" -f $link.Name, $item.LinkType, $actualTarget)
    }
}

# --- (c) settings.json parses; secrets deny baseline intact --------------------
Write-Output ""
Write-Output "== Check C: settings.json =="
# Baseline hardcoded from the actual settings.json on 2026-07-08. Rules may be
# ADDED (then update this baseline via claude-config-change-control); a removal
# is a change-control 2a red flag - surface it to the owner, never update this
# baseline to match a removal.
$expectedDeny = @(
    'Read(**/.env)',
    'Read(**/.env.*)',
    'Read(**/*.pem)',
    'Read(**/*.key)',
    'Read(**/id_rsa)',
    'Read(**/id_ed25519)',
    'Read(~/.ssh/**)',
    'Read(~/.aws/**)',
    'Read(~/.claude/.credentials.json)'
)
$settingsPath = Join-Path $repoRoot 'settings.json'
if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    Report 'FAIL' ("settings.json not found at {0}" -f $settingsPath)
} else {
    $settings = $null
    try {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        Report 'PASS' 'settings.json parses as JSON'
    } catch {
        Report 'FAIL' ("settings.json does NOT parse as JSON: {0}" -f $_.Exception.Message)
    }
    if ($settings) {
        $actualDeny = @()
        if ($settings.permissions -and $settings.permissions.deny) {
            $actualDeny = @($settings.permissions.deny)
        }
        $missing = @()
        foreach ($rule in $expectedDeny) {
            if (-not ($actualDeny -ccontains $rule)) { $missing = $missing + @($rule) }
        }
        if ($missing.Count -eq 0) {
            Report 'PASS' ("all {0} baseline secrets deny rules present" -f $expectedDeny.Count)
        } else {
            foreach ($rule in $missing) {
                Report 'FAIL' ("secrets deny rule MISSING: {0}" -f $rule)
            }
        }
        $extra = @()
        foreach ($rule in $actualDeny) {
            if (-not ($expectedDeny -ccontains $rule)) { $extra = $extra + @($rule) }
        }
        foreach ($rule in $extra) {
            Report 'INFO' ("deny rule beyond baseline (fine, consider adding to baseline): {0}" -f $rule)
        }
    }
}

# --- (d) CLAUDE.md line budget (warning only) -----------------------------------
Write-Output ""
Write-Output "== Check D: CLAUDE.md line budget =="
$claudeMdPath = Join-Path $repoRoot 'CLAUDE.md'
if (Test-Path -LiteralPath $claudeMdPath -PathType Leaf) {
    # Budget source: the HTML maintainer comment at the top of CLAUDE.md ("keep
    # this file under ~120 lines"). Soft budget -> WARN, never FAIL.
    $lineCount = @(Get-Content -LiteralPath $claudeMdPath).Count
    if ($lineCount -gt 120) {
        Report 'WARN' ("CLAUDE.md is {0} lines - over the ~120-line budget; trim before adding more" -f $lineCount)
    } else {
        Report 'PASS' ("CLAUDE.md is {0} lines (budget ~120)" -f $lineCount)
    }
}

# --- Summary --------------------------------------------------------------------
Write-Output ""
Write-Output ("doctor summary: {0} FAIL, {1} WARN" -f $script:fails, $script:warns)
if ($script:fails -gt 0) {
    Write-Output "result: FINDINGS - see FAIL lines above (triage: claude-config-debugging)"
    exit 1
} else {
    Write-Output "result: HEALTHY"
    exit 0
}
