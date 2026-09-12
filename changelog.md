# Changes

## 2026

### 13th of September

- Fix: TLS failures now produce scalar result values instead of occasionally embedding a previous SSL result object
- Fix: CRL and AIA addresses are extracted and matched by hostname instead of broad string matching
- Fix: Proxy certificate substitution is detected by comparing direct and proxy certificate thumbprints
- Update: Certificate issuer and interception details are retained when certificate validation fails

### 11th of September

- Add: Route-aware HTTP and HTTPS testing for direct, environment, Windows Settings, and WinHTTP connections
- Add: Proxy route, bypass, and error details to CSV and grid results
- Add: TLS certificate inspection through HTTP CONNECT proxies
- Update: Result comparisons now match endpoint and connection method, including routes present in only one run
- Update: Bootstrap web requests use the selected proxy routing policy

### 1st of September

- Add: TrustMeBro Artificial Service Area for custom URL ID 10000
- Add: Custom-only `TrustMeBro` parameter set that is exclusive from other Artificial Service Areas and Products and excluded from `TestAllServiceAreas`
- Update: Grouped test parameters and functions into Artificial Service Areas and Products
- Update: Expanded [README.MD](README.MD) with parameter references, supported combinations, examples, expected Intune runtime, and overlapping service-area dependencies

### 25th of January

- Fix: Win32 App and Script endpoints were swapped
- Fix: Fixed minor formatting issue in [ID-to-Service-List.md](ID-to-Service-List.md)
- Add: WIP [Consolidated-List-No-Wildcards.csv](Consolidated-List-No-Wildcards.csv) to enhance Microsofts consolidated list

## 2025

### 3rd of November

- Fix: AIA URIs are now tested additionally tested for TLS inspection (instead of only CRL URIs)
- Fix: #1 - Added multiple new paths to provide CSVs (or don't and let the autodetection do it ;)).

### 13th of October

- Add: [ID-to-Service-List](ID-to-Service-List.md) documentation file to provide mapping of custom IDs to services and lists
- Add: #2 added new check for NuGet endpoints

### 09th of October

- Add: [MCC](MCC.csv) endpoints for standalone MCC installations.
- Update: Delivery Optimization endpoints

### 29th of August

- Add: Microsoft Defender for Endpoint Endpoints
- Fix: Parameter sets should now work as intended

### 4th of August

- Add: ASA for Visual Studio
- Fix: a couple minor errors

### 2nd of July

- Update: azureedge.net is not officially supported since March 2025
- NOTE: While I updated my .csv, the JSON at least as of today still contains the azureedge.net endpoints

## 2024

### 28th of December - Version 1.2.2

- New: Added AppAndScript switch
- Add: Fixed domains from MC964310 <https://mc.merill.net/message/MC964310>

### 10th of December - Version 1.2.1

- New: Created a first release
- Add: zScaler IPS should now be successfully detected

### 1th of October - Version 1.2

- Add: BrienMode added - this allows you to run the script multiple times on the same machine. See parameter description in the script.
- Fix: Several descriptions fixed
- Fix: Added some more logging messages
- Mod: Initialize-Script was adjusted

### 5th of September 2024 - Version 1.1

- Add: Universal Print
- Note: This wasn't published as its own version

### 21th of August 2024 - Version 1.1

- Fix: Small error in handling the timestamp from the filename
- Add: New function Write-SettingsToLog
- Fix: Minor comment additions for an upcoming cleanup
