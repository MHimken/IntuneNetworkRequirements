# Intune Network Requirements

Intune Network Requirements (INR) tests whether a device can reach the endpoints required by Intune, Windows, Microsoft 365, and related products. The [companion article](https://manima.de/2024/08/intune-network-requirements-everything-i-learned/) explains the methodology and interpretation of the results.

## Requirements

- PowerShell 7 or later
- Administrator rights when testing the currently configured NTP server
- An unmanaged reference network and the managed network you want to investigate

Run the same test at least once on each network. Comparing both results is more reliable than interpreting one run because Microsoft does not document an expected response for every endpoint.

## Tests

For each selected endpoint, INR can perform these checks in order:

1. DNS resolution and sinkhole detection
2. TCP connectivity, or supported UDP-specific checks
3. HTTP or HTTPS response
4. TLS negotiation and certificate inspection

Certificate revocation list verification and SSL inspection detection are available with `-CheckCertRevocation`.

## URL Sources

| Parameter | Source |
| --- | --- |
| `-UseMSJSON` | Downloads Microsoft Endpoint Manager endpoints from the Microsoft endpoint service. |
| `-UseMS365JSON` | Downloads Microsoft 365 endpoints. Use `-TenantName` where tenant-specific URLs are required. |
| `-CustomURLFile` | Imports URL, port, protocol, and ID values from a CSV file. |

When no custom filename is supplied in a compatible mode, the script attempts to load `INRCustomList.csv` from the script directory.

```powershell
.\Get-IntuneNetworkRequirements.ps1 -UseMSJSON -Intune -OutputCSV
```

```powershell
.\Get-IntuneNetworkRequirements.ps1 -CustomURLFile .\INRCustomList.csv -Autopilot -ShowResults
```

## Artificial Service Areas

Artificial Service Areas group endpoint IDs into practical test scenarios.

| Parameter | Test area |
| --- | --- |
| `-Intune` | Combined Intune requirements. A run can take 15-20 minutes. |
| `-Autopilot` | Combined Windows Autopilot requirements. |
| `-WindowsActivation` | Windows activation. |
| `-EntraID` | Microsoft Entra ID connectivity. |
| `-WindowsUpdate` | Windows Update, excluding Delivery Optimization. |
| `-DeliveryOptimization` | Delivery Optimization endpoints and local service checks. |
| `-NTP` | Default and configured network time servers. |
| `-DNS` | Public DNS servers; results are written to the log rather than the result CSV. |
| `-DiagnosticsData` | Windows diagnostic data endpoints. |
| `-DiagnosticsDataUpload` | Intune diagnostic collection uploads. |
| `-NCSI` | Network Connectivity Status Indicator endpoints. |
| `-WindowsNotificationService` | Windows Push Notification Service dependencies. |
| `-WindowsStore` | Microsoft Store and Store update endpoints. |
| `-M365` | Microsoft 365 endpoints. This can take several minutes. |
| `-CRLs` | Known Microsoft and custom certificate revocation list endpoints. |
| `-SelfDeploying` | Autopilot self-deploying and pre-provisioning requirements. |
| `-RemoteHelp` | Intune Remote Help endpoints. |
| `-TPMAttestation` | TPM attestation endpoints. |
| `-DeviceHealth` | Microsoft Azure Attestation and device health endpoints. |
| `-Apple` | Apple device-management dependencies. |
| `-Android` | Android and Android Open Source Project dependencies. |
| `-EndpointAnalytics` | Endpoint Analytics endpoints. |
| `-AppInstaller` | App Installer and WinGet requirements. |
| `-UniversalPrint` | Universal Print client requirements. |
| `-AppAndScript` | Win32, Windows script, macOS app, and macOS script deployment domains. |
| `-NuGet` | PowerShell Gallery connectivity using the default NuGet provider. |

### Overlapping Service Areas

Some Artificial Service Areas are composite tests and automatically run other areas. Adding those child areas explicitly does not broaden the test and can repeat function calls.

| Selected area | Areas also tested automatically |
| --- | --- |
| `-Intune` | Autopilot, Remote Help, Windows Notification Service, Delivery Optimization, Apple, Android, Windows Store, Device Health, Windows Update, Endpoint Analytics, Diagnostics Data, NTP, and App and Script deployment. |
| `-Autopilot` | Windows Activation, Entra ID, Diagnostics Data Upload, Windows Update, Delivery Optimization, NTP, DNS, Diagnostics Data, NCSI, Windows Notification Service, Windows Store, CRLs, Legacy, Self-Deploying, and TPM Attestation. |
| `-WindowsStore` | Windows Notification Service and Delivery Optimization. |
| `-AppInstaller` | Windows Store, which also includes Windows Notification Service and Delivery Optimization. |
| `-EntraID` | CRLs, except when Entra ID is already running as part of Autopilot or `-TestAllServiceAreas`. |

For example, do not add `-Autopilot`, `-WindowsUpdate`, or `-TPMAttestation` to an `-Intune` run. Likewise, an `-Autopilot` run does not need those narrower Autopilot dependencies specified separately.

Some otherwise separate areas also share endpoint IDs:

| Areas | Shared IDs | Notes |
| --- | --- | --- |
| Windows Update and Delivery Optimization | 164, 172 | Both test part of the Windows content-delivery path. |
| TPM Attestation and Self-Deploying | 173, 9998 | Both currently select the same endpoint groups. |
| Diagnostics Data and Endpoint Analytics | 69 | Endpoint Analytics adds its own IDs as well. |
| Windows Store and App Installer | 9996 | App Installer delegates to the Windows Store test. |
| NTP and NCSI | 165 | NCSI filters out port 123, so the two tests use different entries from this mixed ID. |

Repeated endpoint objects are skipped by `Test-Network`, so overlapping selections should not create duplicate result rows. They can still repeat setup work and log messages, which is another reason to choose the narrowest applicable areas.

### Choosing Test Combinations

A normal test combines a URL source, one or more Artificial Service Areas or Products, optional test settings, and an output method. Multiple non-nested Artificial Service Areas can be selected in the same run.

Testing specific service areas is recommended because it produces a smaller, faster, and more relevant result set. Use the broader `-Intune` test when the source of the issue is unclear; expect that test to run for approximately 15-20 minutes.

Test common Autopilot enrollment dependencies:

```powershell
.\Get-IntuneNetworkRequirements.ps1 -UseMSJSON -Autopilot -OutputCSV
```

Test Windows Update and Delivery Optimization together:

```powershell
.\Get-IntuneNetworkRequirements.ps1 -UseMSJSON -WindowsUpdate -DeliveryOptimization -NCSI -ShowResults
```

Test Microsoft Store, WinGet, and application deployment:

```powershell
.\Get-IntuneNetworkRequirements.ps1 -CustomURLFile .\INRCustomList.csv -AppInstaller -AppAndScript -NuGet -OutputCSV
```

Test device-management dependencies for Apple and Android:

```powershell
.\Get-IntuneNetworkRequirements.ps1 -UseMSJSON -Apple -Android -OutputCSV -ToConsole
```

Run the broad Intune test when the affected component is unknown:

```powershell
.\Get-IntuneNetworkRequirements.ps1 -UseMSJSON -Intune -AllowBestEffort -CheckCertRevocation -OutputCSV
```

Run the same targeted tests twice to compare two network environments:

```powershell
.\Get-IntuneNetworkRequirements.ps1 -UseMSJSON -Autopilot -BrienMode 2 -OutputCSV -ShowResults
```

`-TestAllServiceAreas` runs the standard Artificial Service Areas. It requires both Microsoft URL sources and a tenant name.

```powershell
.\Get-IntuneNetworkRequirements.ps1 -TestAllServiceAreas -UseMSJSON -UseMS365JSON -TenantName contoso -OutputCSV
```

Use `-GCC` to select GCC-specific Remote Help, Device Health, and Universal Print endpoints where supported.

## TrustMeBro

`-TrustMeBro` tests custom URL entries with ID 10000. It runs only in Custom mode, is not included in `-TestAllServiceAreas`, and cannot be combined with another Artificial Service Area or Product.

```powershell
.\Get-IntuneNetworkRequirements.ps1 -CustomURLFile .\INRCustomList.csv -TrustMeBro -ToConsole
```

## Products

Products are separate from `-TestAllServiceAreas` and require the corresponding CSV data.

| Parameter | Product test |
| --- | --- |
| `-ConnectedCache` | Microsoft Connected Cache. Use `MCC.csv`. |
| `-VisualStudioFull` | All listed Visual Studio endpoints. Use `VisualStudio.csv`. |
| `-VisualStudioInstallation` | Endpoints required to install Visual Studio. Use `VisualStudio.csv`. |
| `-DefenderFull` | All listed Microsoft Defender for Endpoint requirements. Use `MicrosoftDefender.csv`. |
| `-DefenderOptional` | Optional Defender endpoints. |
| `-DefenderLiveResponse` | Defender Live Response. |
| `-DefenderVulnTool` | Defender Vulnerability Management. |
| `-DefenderSmartScreen` | Microsoft Defender SmartScreen. |

```powershell
.\Get-IntuneNetworkRequirements.ps1 -CustomURLFile .\VisualStudio.csv -VisualStudioFull -CheckCertRevocation -OutputCSV -ShowResults
```

```powershell
.\Get-IntuneNetworkRequirements.ps1 -CustomURLFile .\MicrosoftDefender.csv -DefenderFull -OutputCSV
```

## Standalone Checks

| Parameter | Check |
| --- | --- |
| `-AuthenticatedProxyOnly` | Checks for an authenticated proxy without selecting another area. |
| `-TestSSLInspectionOnly` | Checks for TLS inspection without selecting another area. |
| `-Legacy` | Reserved for a future legacy-service test and currently not implemented. |

## Options

| Parameter | Behavior |
| --- | --- |
| `-AllowBestEffort` | Converts unresolved wildcard entries into testable hostnames using best-effort matching. |
| `-CheckCertRevocation` | Verifies certificate CRL or AIA locations against known entries. The source data must include IDs 84, 125, or 9993. |
| `-MaxDelayInMS` | Maximum TCP response delay. The default is 300 ms. |
| `-BurstMode` | Repeats TCP checks in 50 ms increments up to `MaxDelayInMS`. |
| `-BrienMode` | Runs the selected tests repeatedly and compares the two latest results. A value of 2 is recommended. |

## Output

| Parameter | Behavior |
| --- | --- |
| `-OutputCSV` | Writes result CSV files beneath the working directory. |
| `-ShowResults` | Opens results in `Out-GridView`. |
| `-ToConsole` | Writes log messages to the console instead of creating a log file. |
| `-NoOutput` | Disables log output. |
| `-WorkingDirectory` | Sets the working and result directory. The script directory is used by default. |
| `-LogDirectory` | Sets the log directory. The `Logs` folder under the working directory is used by default. |

## Comparing Results

Use `-MergeResults` with two CSV filenames to compare runs. Add `-MergeShowAllResults` to include unchanged entries in the merged output.

```powershell
.\Get-IntuneNetworkRequirements.ps1 -MergeResults -MergeCSVs ResultList_Reference.csv,ResultList_Managed.csv -ShowResults
```

When filenames are omitted, the script attempts to select the two latest result files automatically.
