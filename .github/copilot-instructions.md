See [AGENTS.md](../AGENTS.md) at the repository root for full agent guidance.

Key points (full detail in AGENTS.md):

- PowerShell 7+ on Windows (WPF GUI). End-user docs: `instructions.md`.
- Two codebases here:
  - `Get-IntuneNetworkRequirements.ps1` is vendored upstream - do not refactor
    or restyle it; make minimal changes only.
  - `Start-INRWithGUI.ps1`, `Modules/INR.*.psm1`, and `GUI/MainWindow.xaml` are
    the owned wrapper - use modern style here.
- The wrapper drives the scanner by shelling out to `pwsh.exe` and parsing
  stdout. Fragile seams: stdout progress markers the core script emits natively
  (verified read-only by `Test-INRScriptMarker`; keep `$script:RequiredScriptMarkers`
  in sync), CLI parameter names, `TestResults\ResultList_<date>_<host>.csv` paths,
  and the ASA list duplicated in ~3 places. Change them in sync.
- Owned-code conventions: `Set-StrictMode -Version Latest`, `INR` noun prefix
  with approved verbs, `List[T]`, `[pscustomobject]`, atomic writes, encode
  values placed into HTML reports.
- Verify with `pwsh -NoProfile -File Tests/Invoke-INRAnalyzer.ps1` and
  `pwsh -NoProfile -File Tests/Invoke-INRTests.ps1` (add `-CI` to fail on error).
- Use plain ASCII only: no em/en dashes, smart quotes, ellipsis char, or
  non-breaking spaces.
