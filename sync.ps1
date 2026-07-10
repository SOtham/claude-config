# sync.ps1 - Package ~/.claude/skills for claude.ai upload.
#
# Canonical source: C:\Dev\claude-config\skills\, reached via the ~/.claude
# links (same files; local Claude Code picks edits up automatically).
# This script only rebuilds the upload zips: each skills/<name>/ folder becomes
# dist/<name>.zip with the skill folder at the zip root and forward-slash entry
# paths (Compress-Archive in PS 5.1 writes backslashes, which Linux extractors
# treat as literal filename characters).
#
# Run after editing any SKILL.md, then re-upload the changed zips to
# claude.ai > Settings > Capabilities > Skills.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$skills = Join-Path $root 'skills'
$dist   = Join-Path $root 'dist'

New-Item -ItemType Directory -Force $dist | Out-Null

Get-ChildItem $skills -Directory | ForEach-Object {
    $name = $_.Name
    $zip  = Join-Path $dist ($name + '.zip')
    if (Test-Path $zip) { Remove-Item $zip -Force -Confirm:$false }
    $archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
    try {
        Get-ChildItem $_.FullName -Recurse -File | ForEach-Object {
            $rel = $name + '/' + ($_.FullName.Substring((Join-Path $skills $name).Length + 1) -replace '\\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $rel) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
    Write-Output ("packaged {0} -> dist\{0}.zip" -f $name)
}

Write-Output ""
Write-Output "Zips rebuilt. Upload changed ones to claude.ai > Settings > Capabilities > Skills."
