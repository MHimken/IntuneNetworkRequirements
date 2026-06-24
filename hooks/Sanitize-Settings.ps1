#!/usr/bin/env pwsh
# Sanitizer invoked by the pre-commit hook (hooks/pre-commit).
#
# Settings.json is gitignored and should never be committed. This is
# defense-in-depth: if Settings.json is ever staged anyway (for example via
# `git add -f`, or because the ignore rule was removed), it blanks the
# PII-bearing path fields CompareCsvA / CompareCsvB before the commit is
# recorded, then re-stages the cleaned file.
$ErrorActionPreference = 'Stop'

# Only act when Settings.json is part of this commit.
$staged = @(git diff --cached --name-only)
if ($staged -notcontains 'Settings.json') { exit 0 }

$root = (git rev-parse --show-toplevel).Trim()
$path = Join-Path $root 'Settings.json'
if (-not (Test-Path -LiteralPath $path)) { exit 0 }

$content = Get-Content -LiteralPath $path -Raw

# Match "CompareCsvA": "..." (and B), tolerating escaped characters such as the
# doubled backslashes in Windows paths, and replace the value with "".
$pattern = '("CompareCsv[AB]"\s*:\s*)"(?:[^"\\]|\\.)*"'
$blanked = [regex]::Replace($content, $pattern, '$1""')

if ($blanked -ne $content) {
    # -NoNewline preserves the file's existing trailing newline exactly.
    Set-Content -LiteralPath $path -Value $blanked -NoNewline -Encoding utf8
    git add -- 'Settings.json'
    Write-Warning 'pre-commit: blanked CompareCsvA/CompareCsvB in Settings.json (local PII paths removed before commit).'
}

exit 0
