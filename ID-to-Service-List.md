# ID mapping to service and list

This list is used to map the custom IDs used in several '(artificial) service areas' to their respective services and the lists they are used in. This list does not include the standard IDs provided by Microsoft, only the custom ones created to cover gaps in the official lists or to separate services into more manageable parts.

| ID | Service(s) | Used in List | Notes |
| ---- | ------------ | -------------- | ------- |
| 999 | DNS Servers | [INR CustomList](INRCustomList.csv) | |
| 9999 | Autopilot | [INR CustomList](INRCustomList.csv) | |
| 9998 | TPM Attestation | [INR CustomList](INRCustomList.csv) | Used instead of wildcard - no TLS inspection allowed |
| 9997 | Intune Management | [INR CustomList](INRCustomList.csv) | Used instead of wildcard - no TLS inspection allowed |
| 9996 | Microsoft Store | [INR CustomList](INRCustomList.csv) | Microsoft JSON does not contain any |
| 9995 | Health Attestation | [INR CustomList](INRCustomList.csv) | These are for GCC only |
| 9994 | Delivery Optimization | [INR CustomList](INRCustomList.csv) | Only documented on [DO FAQ](https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-faq#what-hostnames-should-i-allow-through-my-firewall-to-support-delivery-optimization?WT.mc_id=MVP_444422) |
| 9993 | Certificate Revocation Lists | [INR CustomList](INRCustomList.csv) | These are the well known CRLs by Apple and Google |
| 9992 | Android Service | [INR CustomList](INRCustomList.csv) | These are the  Android service endpoints provided by Google |
| 9991 | Windows Activation | [INR CustomList](INRCustomList.csv) | These are the Windows Activation service endpoints provided according to several Microsoft documentations |
| 9990 | Entra ID Authentication | [INR CustomList](INRCustomList.csv) | These are the [Entra ID authentication service endpoints](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/tshoot-connect-connectivity#connectivity-issues-in-the-installation-wizard?WT.mc_id=MVP_444422) |
| 9989 | Diagnostics Data Upload | [INR CustomList](INRCustomList.csv) | These are the Diagnostics Data Upload service endpoints missing from Microsofts list |
| 9988 | Endpoint Analytics | [INR CustomList](INRCustomList.csv) | These are the Endpoint Analytics service endpoints |
| 9987 | Network Indicator Test | [INR CustomList](INRCustomList.csv) | These are the Network Indicator Test service endpoints |
| 9986 | Authenticated Proxy not allowed | [INR CustomList](INRCustomList.csv) | These URLs cannot be accessed through an authenticated proxy |
| 9985 | TLS inspection not allowed | [INR CustomList](INRCustomList.csv#L50) | These URLs cannot be inspected by TLS |
| 9984 | Compatibility Database Updates | [INR CustomList](INRCustomList.csv) | These URLs are for compatibility database updates |
| 9983 | Microsoft Telemetry | [INR CustomList](INRCustomList.csv) | These URLs are for Microsoft telemetry data collection required for endpoint analytics |
| 9982 | Universal Print | [INR CustomList](INRCustomList.csv) | These URLs are for Universal Print service |
| 9981 | Universal Print GCC | [INR CustomList](INRCustomList.csv) | These URLs are for Universal Print service - GCC |
| 9980 | Universal Print Telemetry | [INR CustomList](INRCustomList.csv) | These URLs are for Universal Print service - telemetry for analytics |
| 9979 | Intune Win32 App | [INR CustomList](INRCustomList.csv) | These URLs are for Intune Win32 App download - highly location-dependent |
| 9978 | Visual Studio - Basic Download | [VisualStudio](VisualStudio.csv) | These URLs are for Visual Studio downloads and updates |
| 9977 | Visual Studio - Third Party Download | [VisualStudio](VisualStudio.csv) | These URLs are for Visual Studio downloads and updates |
| 9976 | Visual Studio - All other | [VisualStudio](VisualStudio.csv) | These URLs are for Visual Studio downloads and updates |
| 9975 | NuGet | [INR CustomList](INRCustomList.csv) | These URLs are for NuGet package manager |
| 5000 | MCC - Core | [MCC](MCC.csv) | Windows Update, Windows Defender, Windows Drivers, Windows Store, Windows Drivers, Windows Store plus Edge and MCC to Delivery Optimization service communications |
| 5001 | MCC - Office |[MCC](MCC.csv) | Office Updates |
| 5002 | MCC - Intune Win32 Apps |[MCC](MCC.csv) | Intune Win32 Apps |
| 5003 | MCC - Teams |[MCC](MCC.csv) | Teams |
| 5004 | MCC - Outlook |[MCC](MCC.csv) | Outlook |
| 5005 | MCC - Xbox |[MCC](MCC.csv) | Xbox |
| 5006 | MCC - Device Update |[MCC](MCC.csv) | [Device Update](https://learn.microsoft.com/azure/iot-hub-device-update/?WT.mc_id=MVP_444422) |
| 5007 | MCC - IoT |[MCC](MCC.csv) | IoT Edge / IoT Hub communication |
| 5008 | MCC - Ubuntu |[MCC](MCC.csv) | Ubuntu package updates |
| 5009 | MCC - Microsoft Packages |[MCC](MCC.csv) | Microsoft package updates |
| 5010 | MCC - Azure IoT | [MCC](MCC.csv) | Azure IoT Identity Service |
| 6003 | Microsoft Defender for Endpoint (optional) | [MicrosoftDefender](MicrosoftDefender.csv) | Microsoft Vulnerability Management |
| 6002 | Microsoft Defender for Endpoint (optional) | [MicrosoftDefender](MicrosoftSignIn.csv) | Microsoft Live Response |
| 6001 | Microsoft Defender for Endpoint (optional)  | [MicrosoftDefender](SmartScreen.csv) | SmartScreen |
| 6000 | Microsoft Defender for Endpoint (required) | [MicrosoftDefender](MicrosoftDefender.csv) | Microsoft Defender for Endpoint core |
