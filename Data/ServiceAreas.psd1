#
# ServiceAreas.psd1 - single source of truth for the Intune Network Requirements
# service-area (ASA) catalog.
#
# Consumed by:
#   * Get-IntuneNetworkRequirements.ps1  (builds its tests and -Switch dispatch)
#   * Modules/INR.Validation.psm1        (builds the GUI ASA list and rules)
#
# Field reference (per entry):
#   Name           Canonical name. Equals the script switch parameter and the
#                  GUI list label. The progress marker emits "(Function: Test-<Name>)".
#   Code           Short service-area code used in log lines / -Component.
#   Function       The script function that runs this area.
#   Handler        'Generic' = handled by Invoke-INRServiceAreaTest (URL loop only).
#                  'Custom'  = the named function contains bespoke logic.
#   ServiceIds     URL IDs to resolve for this area.
#   GccServiceIds  Replacement ID set when -GCC is supplied (optional).
#   FilterPort     Ports to exclude when resolving URLs (optional).
#   Group          Areas sharing a Group run their Function once (e.g. Defender).
#   IncludedInAll  Runs when -TestAllServiceAreas is supplied.
#   ShowInGui      Listed as a selectable area in the WPF launcher.
#   Additional     One of the "additional" areas (shown in GUI, excluded from All).
#   PreMessages    Informational log lines emitted before testing (optional).
#   Notes          Free-form documentation / source links (optional).
#
@{
    ServiceAreas = @(
        @{
            Name = 'Intune'; Code = 'Int'; Function = 'Test-Intune'; Handler = 'Custom'
            ServiceIds = @(56, 150, 59, 163, 172, 170, 97, 190, 189, 9998, 9985, 9997)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints'
        }
        @{
            Name = 'Autopilot'; Code = 'AP'; Function = 'Test-Autopilot'; Handler = 'Custom'
            ServiceIds = @(9999)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = '9999 = Autopilot. https://learn.microsoft.com/en-us/autopilot/requirements'
        }
        @{
            Name = 'WindowsActivation'; Code = 'WinAct'; Function = 'Test-WindowsActivation'; Handler = 'Generic'
            ServiceIds = @(9991)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            PreMessages = @('These following URLs are best effort - there is very little documentation about this')
            Notes = 'https://support.microsoft.com/en-us/topic/windows-activation-or-validation-fails-a9afe65e'
        }
        @{
            Name = 'EntraID'; Code = 'EID'; Function = 'Test-EntraID'; Handler = 'Custom'
            ServiceIds = @(9990)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            PreMessages = @('The following URLs are the bare minimum for EntraID to work - depending on the situation there might be more')
            Notes = 'Also pulls CRL IDs 125/84. https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/tshoot-connect-connectivity'
        }
        @{
            Name = 'WindowsUpdate'; Code = 'WU'; Function = 'Test-WindowsUpdate'; Handler = 'Generic'
            ServiceIds = @(164, 172, 9984)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/troubleshoot/windows-client/installing-updates-features-roles/windows-update-issues-troubleshooting'
        }
        @{
            Name = 'DeliveryOptimization'; Code = 'DO'; Function = 'Test-DeliveryOptimization'; Handler = 'Custom'
            ServiceIds = @(172, 164, 9994); FilterPort = @(7680, 3544)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints#delivery-optimization-dependencies'
        }
        @{
            Name = 'NTP'; Code = 'NTPServers'; Function = 'Test-NTP'; Handler = 'Custom'
            ServiceIds = @(165); FilterPort = @(80, 443)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints#autopilot-dependencies'
        }
        @{
            Name = 'DNS'; Code = 'DNSServer'; Function = 'Test-DNSServers'; Handler = 'Custom'
            ServiceIds = @(999)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'Log-only output. Tests a mixture of public DNS servers.'
        }
        @{
            Name = 'DiagnosticsData'; Code = 'Diagnostics'; Function = 'Test-DiagnosticsData'; Handler = 'Generic'
            ServiceIds = @(69, 9983)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/windows/privacy/manage-windows-11-endpoints'
        }
        @{
            Name = 'DiagnosticsDataUpload'; Code = 'DiagnosticsUpload'; Function = 'Test-DiagnosticsDataUpload'; Handler = 'Generic'
            ServiceIds = @(182, 9989)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'Autopilot automatic device diagnostics collection.'
        }
        @{
            Name = 'NCSI'; Code = 'NetworkIndicator'; Function = 'Test-NCSI'; Handler = 'Custom'
            ServiceIds = @(165, 9987); FilterPort = @(123)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'Service ID 165 is mixed with NTP; 9987 isolates the correct URLs/ports.'
        }
        @{
            Name = 'WindowsNotificationService'; Code = 'WNS'; Function = 'Test-WNS'; Handler = 'Generic'
            ServiceIds = @(169, 171)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints#windows-push-notification-serviceswns-dependencies'
        }
        @{
            Name = 'WindowsStore'; Code = 'MS'; Function = 'Test-MicrosoftStore'; Handler = 'Custom'
            ServiceIds = @(9996)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints#microsoft-store'
        }
        @{
            Name = 'M365'; Code = 'MS365'; Function = 'Test-M365'; Handler = 'Custom'
            ServiceIds = @(41, 43, 44, 45, 46, 47, 49, 50, 51, 53, 56, 59, 64, 66, 67, 68, 69, 70, 71, 73, 75, 78, 79, 83, 84, 86, 89, 91, 92, 93, 95, 96, 97, 105, 114, 116, 117, 118, 121, 122, 124, 125, 126, 147, 152, 153, 156, 158, 159, 160, 184)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'Requires -UseMS365JSON. Tests every M365 Common URL. https://learn.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges'
        }
        @{
            Name = 'CRLs'; Code = 'CRL'; Function = 'Test-CRL'; Handler = 'Generic'
            ServiceIds = @(84, 125, 9993)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            PreMessages = @('CRLs should only ever be available through Port 80, however the MS-JSON specifies 443 as well. Expect errors going forward')
            Notes = 'Well-known Microsoft CRLs plus custom ID 9993 from INRCustomList.csv.'
        }
        @{
            Name = 'SelfDeploying'; Code = 'SelfDepl'; Function = 'Test-SelfDeploying'; Handler = 'Generic'
            ServiceIds = @(173, 9998)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/autopilot/requirements#autopilot-self-deploying-mode-and-autopilot-pre-provisioning'
        }
        @{
            Name = 'RemoteHelp'; Code = 'RemoteHelp'; Function = 'Test-RemoteHelp'; Handler = 'Generic'
            ServiceIds = @(181, 187, 189); GccServiceIds = @(181, 187, 188, 189)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints#remote-help'
        }
        @{
            Name = 'TPMAttestation'; Code = 'TPMAtt'; Function = 'Test-TPMAttestation'; Handler = 'Generic'
            ServiceIds = @(173, 9998)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/autopilot/requirements#autopilot-self-deploying-mode-and-autopilot-pre-provisioning'
        }
        @{
            Name = 'DeviceHealth'; Code = 'DeviceHealth'; Function = 'Test-DeviceHealth'; Handler = 'Generic'
            ServiceIds = @(186); GccServiceIds = @(186, 9995)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'Microsoft Azure Attestation (formerly Device Health).'
        }
        @{
            Name = 'Apple'; Code = 'Apple'; Function = 'Test-Apple'; Handler = 'Generic'
            ServiceIds = @(178)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            PreMessages = @(
                'Port 5223 is only used as a fallback for push notifications and only valid for push.apple.com addresses',
                'Warning: Other URLs might be required, please also consult https://support.apple.com/en-us/101555'
            )
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints#apple-dependencies'
        }
        @{
            Name = 'Android'; Code = 'Android'; Function = 'Test-Android'; Handler = 'Custom'
            ServiceIds = @(179, 9992)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/intune/fundamentals/intune-endpoints#android-aosp-dependencies'
        }
        @{
            Name = 'EndpointAnalytics'; Code = 'EndpAnalytics'; Function = 'Test-EndpointAnalytics'; Handler = 'Generic'
            ServiceIds = @(69, 163, 9988)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/mem/analytics/troubleshoot#bkmk_endpoints'
        }
        @{
            Name = 'AppInstaller'; Code = 'AppInstall'; Function = 'Test-AppInstaller'; Handler = 'Custom'
            ServiceIds = @(9996)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'winget. Same requirements as the Microsoft Store.'
        }
        @{
            Name = 'UniversalPrint'; Code = 'UniP'; Function = 'Test-UniversalPrint'; Handler = 'Generic'
            ServiceIds = @(9982, 9980); GccServiceIds = @(9981, 9980)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'https://learn.microsoft.com/en-us/universal-print/fundamentals/universal-print-faqs'
        }
        @{
            Name = 'AppAndScript'; Code = 'W32Script'; Function = 'Test-AppAndScripts'; Handler = 'Generic'
            ServiceIds = @(170, 9979)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'Win32 app and PowerShell script deployment (Windows + macOS).'
        }
        @{
            Name = 'NuGet'; Code = 'NuGet'; Function = 'Test-NuGet'; Handler = 'Generic'
            ServiceIds = @(9975)
            IncludedInAll = $true; ShowInGui = $true; Additional = $false
            Notes = 'PowerShell Gallery / NuGet provider.'
        }
        @{
            Name = 'ConnectedCache'; Code = 'MCC'; Function = 'Test-ConnectedCache'; Handler = 'Generic'
            ServiceIds = @(5000, 5001, 5002, 5003, 5004, 5005, 5006, 5007, 5008, 5009, 5010); FilterPort = @(7680, 3544)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            PreMessages = @('This service area will also test for MCC domains being available')
            Notes = 'Microsoft Connected Cache. https://learn.microsoft.com/en-us/windows/deployment/do/delivery-optimization-endpoints'
        }
        @{
            Name = 'VisualStudioFull'; Code = 'VSt'; Function = 'Test-VisualStudio'; Handler = 'Custom'; Group = 'VisualStudio'
            ServiceIds = @(9976)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            Notes = 'Adds full Visual Studio usage IDs on top of the installation set.'
        }
        @{
            Name = 'VisualStudioInstallation'; Code = 'VSt'; Function = 'Test-VisualStudio'; Handler = 'Custom'; Group = 'VisualStudio'
            ServiceIds = @(9978, 9977, 56, 89, 97)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            Notes = 'Base Visual Studio installation endpoints. https://learn.microsoft.com/en-us/visualstudio/install/install-and-use-visual-studio-behind-a-firewall-or-proxy-server'
        }
        @{
            Name = 'DefenderFull'; Code = 'Defender'; Function = 'Test-MDE'; Handler = 'Custom'; Group = 'Defender'
            ServiceIds = @(6000)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            Notes = '6000 = Core. https://aka.ms/MDE-streamlined-urls'
        }
        @{
            Name = 'DefenderOptional'; Code = 'Defender'; Function = 'Test-MDE'; Handler = 'Custom'; Group = 'Defender'
            ServiceIds = @(6001, 6002, 6003)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            Notes = 'SmartScreen + LiveResponse + VulnerabilityManagement.'
        }
        @{
            Name = 'DefenderLiveResponse'; Code = 'Defender'; Function = 'Test-MDE'; Handler = 'Custom'; Group = 'Defender'
            ServiceIds = @(6002)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            Notes = '6002 = LiveResponse.'
        }
        @{
            Name = 'DefenderVulnTool'; Code = 'Defender'; Function = 'Test-MDE'; Handler = 'Custom'; Group = 'Defender'
            ServiceIds = @(6003)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            Notes = '6003 = VulnerabilityManagement.'
        }
        @{
            Name = 'DefenderSmartScreen'; Code = 'Defender'; Function = 'Test-MDE'; Handler = 'Custom'; Group = 'Defender'
            ServiceIds = @(6001)
            IncludedInAll = $false; ShowInGui = $true; Additional = $true
            Notes = '6001 = SmartScreen.'
        }
        @{
            Name = 'AuthenticatedProxyOnly'; Code = 'AuthenProxy'; Function = 'Test-AuthenticatedProxy'; Handler = 'Custom'
            ServiceIds = @(9986)
            IncludedInAll = $true; ShowInGui = $false; Additional = $false
            Notes = 'URLs that do not allow authenticated proxies.'
        }
        @{
            Name = 'TestSSLInspectionOnly'; Code = 'TLSInspec'; Function = 'Test-SSLInspection'; Handler = 'Custom'
            ServiceIds = @(9985)
            IncludedInAll = $true; ShowInGui = $false; Additional = $false
            Notes = 'URLs incompatible with TLS/SSL inspection.'
        }
        @{
            Name = 'Legacy'; Code = 'Legacy'; Function = 'Test-Legacy'; Handler = 'Custom'
            ServiceIds = @()
            IncludedInAll = $true; ShowInGui = $false; Additional = $false
            Notes = 'Not implemented yet (hybrid join etc.).'
        }
    )
}
