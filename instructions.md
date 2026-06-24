# INRWithGUI - User Instructions

## Purpose

INRWithGUI provides a WPF GUI wrapper around Get-IntuneNetworkRequirements.ps1.
The original script is not modified; execution happens from C:\Temp\INRWithGUI.

## Prerequisites

- PowerShell 7+
- Windows (WPF GUI)
- Network access required by the underlying INR tests

## Start

1. Open PowerShell 7.
2. Run:

   ```powershell
   Set-Location C:\Temp\INRWithGUI
   .\Start-INRWithGUI.ps1
   ```

## Main Features

- Run Scan: Execute network requirement tests.
- Compare Runs (Visual): Build an interactive report comparing two scan result CSVs.

## Run Scan

- Optional custom CSV:
  - Enable Use Custom CSV.
  - Browse one CSV file only.
  - CSV is validated against expected structure (URL, Port, Protocol, ID).
- Source toggles:
  - UseMSJSON
  - UseMS365JSON
  - AllowBestEffort (default ON)
  - CheckCertRevocation (default ON)
- ASA selection:
  - Select one or multiple ASAs in the list.
  - Overlap warnings are shown for known redundant combinations.
  - If an Additional ASA is selected (ConnectedCache, VisualStudio*, Defender*):
    - UseMSJSON and UseMS365JSON are disabled.
    - Custom CSV is required.

## Compare Runs (Visual)

- Select two ResultList CSV files (Run A and Run B).
- Choose the vis.js library mode:
  - Offline (bundled): self-contained report that renders with no internet.
  - Online (CDN): smaller report that loads vis.js from a CDN at view time.
- Generate Visual Comparison builds an HTML report into the Reports folder and opens it.
- In the report, pick which columns to compare. Endpoints are green when all selected
  columns match between the two runs, red when any differ, and amber when an endpoint
  exists on only one side. Run A is anchored on the left, Run B on the right.

## Settings

- Detailed Output:
  - ON: append full status lines.
  - OFF (Simple): show progress and ETA only.
- Simple progress bar:
  - Rainbow-colored bar updates while run is active.
  - ETA recalculates from rolling average endpoint timing.
- Other settings:
  - TenantName
  - MaxDelayInMS
  - BurstMode
  - Dark Mode toggle
  - Create Log File (default ON; off maps to NoOutput)
- Settings are persisted in Settings.json.

## Start / Stop

- Start: begins script execution in a child pwsh process.
- Stop: terminates the active process.

## Visual Reporting

Use Generate Visual Report to create:

- Scan source selection behavior:
  - If a scan has just completed in the current app session, the latest ResultList CSV from that run is used automatically.
  - Otherwise, the app shows "You have not run a scan yet, please select a file" and opens a file selection dialog.
- Scan report (HTML):
  - Hostname -> ASA -> URLs
  - Emoji indicators:
    - DNSResult
    - TCPResult
    - HTTPStatusCode
    - SSLTest
    - SSLInterception

Use Compare Runs (Visual) to build the interactive two-run comparison described above.

## Notes and Limitations

- Endpoint estimate is heuristic and may differ from real total when cloud endpoint sources vary.
- Excel-based export path is not required and is not assumed.

## Troubleshooting

- If GUI does not open, verify PowerShell 7 is used.
- If custom CSV validation fails, verify extension and column shape.
- For Compare Runs, select two valid ResultList CSV files.
