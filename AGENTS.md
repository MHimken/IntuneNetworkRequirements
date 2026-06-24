# AGENTS.md

Guidance for AI coding agents (GitHub Copilot, Claude Code, and similar) working
in this repository. Read this before making changes.

## What this repo is

INRWithGUI is a WPF GUI wrapper around an Intune network-requirements scanner.
It runs on **PowerShell 7+ on Windows** (WPF). End-user docs live in
[instructions.md](instructions.md).

## The two codebases (most important thing to know)

This folder contains two codebases with different ownership and styles. Do not
blur them together.

1. **Vendored upstream (treat as external):** `Get-IntuneNetworkRequirements.ps1`
   - ~2300-line single-file scanner from the upstream project
     `github.com/MHimken/toolbox`.
   - Old style: no `Set-StrictMode`, `ArrayList` + `.Add() | Out-Null`, heavy
     `$Script:` globals, ~30 near-identical `Test-<ASA>` functions, a large
     if-ladder in `Start-Tests`.
   - Do not refactor, restyle, or "clean up" this file. Make the smallest change
     possible and only when required. It is meant to track upstream.

2. **Owned wrapper (the code we maintain):**
   - `Start-INRWithGUI.ps1`, `Modules/INR.*.psm1`, `GUI/MainWindow.xaml`.
   - Modules: `INR.Context`, `INR.Settings`, `INR.Validation`, `INR.Reports`,
     `INR.ServiceCatalog`, `INR.Execution`.
   - Modern style is expected here (see Conventions).

## How the wrapper drives the scanner (fragile coupling)

The wrapper shells out to `pwsh.exe` running the upstream script and parses its
stdout. Several seams break easily, so change them deliberately and in sync:

- The GUI parses progress markers out of the core script's stdout. The core
  script **emits these markers natively** (`URLsToVerify count:`, `(Function: `,
  `TestNetworkResult:`); the wrapper does **not** mutate the script on disk.
  `Test-INRScriptMarker` (in `Modules/INR.Execution.psm1`) does a read-only
  check that those markers are still present and warns if any are missing. If
  you change the upstream script's log strings, update
  `$script:RequiredScriptMarkers` to match (and vice versa).
- CLI parameter names passed to the scanner (`New-INRArgumentList`) must match
  the upstream script's parameters.
- CSV path conventions are load-bearing: `TestResults\ResultList_<date>_<host>.csv`
  and `MergedResults\...`.
- The ASA (Additional Service Area) list is duplicated in ~3 places:
  `Get-INRAvailableASAs`, the upstream switch parameters, and the settings
  defaults (`Save-UiSettings` / `Get-INRDefaultSettings`). Update all of them
  together.

## Conventions (owned code only)

- `Set-StrictMode -Version Latest`.
- Approved verbs, `INR` noun prefix for module functions.
- Use `System.Collections.Generic.List[T]` (not `ArrayList`), `[pscustomobject]`
  for records, and atomic file writes (temp file + move) for outputs.
- HTML reports interpolate CSV values; encode/escape any value placed into HTML
  to avoid injection.

## Build, test, and verify

Run from the repo root with PowerShell 7+:

```powershell
# Static analysis (PSScriptAnalyzer)
pwsh -NoProfile -File Tests/Invoke-INRAnalyzer.ps1

# Unit tests (Pester 5)
pwsh -NoProfile -File Tests/Invoke-INRTests.ps1
```

Add `-CI` to either runner to exit non-zero on failures (used by CI). The CI
workflow is [.github/workflows/ci.yml](.github/workflows/ci.yml); analyzer rules
are in [Tests/PSScriptAnalyzerSettings.psd1](Tests/PSScriptAnalyzerSettings.psd1).
Add or update `*.Tests.ps1` under `Tests/` when changing owned behavior.

## One-time local setup: git hooks

`Settings.json` is gitignored and holds local runtime state, including
`CompareCsvA` / `CompareCsvB` paths that often contain PII (user names, machine
names). A shared pre-commit hook in `hooks/` is defense-in-depth: if
`Settings.json` is ever staged anyway (e.g. `git add -f`), it blanks those two
fields before the commit is recorded.

Hooks live in a tracked `hooks/` directory, so enable them once per clone:

```powershell
git config core.hooksPath hooks
```

The hook requires PowerShell 7+ (`pwsh`) on PATH, which this repo already needs.

## Writing style

Use plain ASCII in all files, comments, and commit messages. Do not use em
dashes, en dashes, smart/curly quotes, the ellipsis character, or non-breaking
spaces. Use `-`, straight quotes `' "`, and three dots `...`.

## Other docs

- [instructions.md](instructions.md): end-user usage.
- `context.md` / `context.json`: auto-appended development log; not authoritative.
