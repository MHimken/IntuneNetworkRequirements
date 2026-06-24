#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RootPath = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$ModulesPath = Join-Path -Path $RootPath -ChildPath 'Modules'
$script:ScriptPath = $MyInvocation.MyCommand.Path

Import-Module (Join-Path $ModulesPath 'INR.Context.psd1') -Force
Import-Module (Join-Path $ModulesPath 'INR.Settings.psd1') -Force
Import-Module (Join-Path $ModulesPath 'INR.ServiceCatalog.psd1') -Force
Import-Module (Join-Path $ModulesPath 'INR.Validation.psd1') -Force
Import-Module (Join-Path $ModulesPath 'INR.Execution.psd1') -Force
Import-Module (Join-Path $ModulesPath 'INR.Reports.psd1') -Force

Initialize-INRContext -RootPath $RootPath
$settings = Import-INRSettings -RootPath $RootPath

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName Microsoft.VisualBasic

function Test-INRIsAdministrator {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

$script:IsAdmin = Test-INRIsAdministrator

[xml]$xaml = Get-Content -LiteralPath (Join-Path $RootPath 'GUI\MainWindow.xaml') -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

function Find-Control([string]$name) { return $window.FindName($name) }

$UseCustomCsvCheck = Find-Control 'UseCustomCsvCheck'
$CustomCsvPathText = Find-Control 'CustomCsvPathText'
$BrowseCustomCsvButton = Find-Control 'BrowseCustomCsvButton'
$UseMSJsonCheck = Find-Control 'UseMSJsonCheck'
$UseMS365JsonCheck = Find-Control 'UseMS365JsonCheck'
$AllowBestEffortCheck = Find-Control 'AllowBestEffortCheck'
$CheckCertRevocationCheck = Find-Control 'CheckCertRevocationCheck'
$AsaList = Find-Control 'AsaList'
$OverlapWarningText = Find-Control 'OverlapWarningText'
$DetailedOutputCheck = Find-Control 'DetailedOutputCheck'
$EnableLogFileCheck = Find-Control 'EnableLogFileCheck'
$OpenCsvWithDefaultProgramCheck = Find-Control 'OpenCsvWithDefaultProgramCheck'
$TenantNameText = Find-Control 'TenantNameText'
$MaxDelayText = Find-Control 'MaxDelayText'
$BurstModeCheck = Find-Control 'BurstModeCheck'
$ResetWindowSizeButton = Find-Control 'ResetWindowSizeButton'
$RainbowProgressHost = Find-Control 'RainbowProgressHost'
$RainbowProgressFill = Find-Control 'RainbowProgressFill'
$RainbowProgressMask = Find-Control 'RainbowProgressMask'
$ProgressText = Find-Control 'ProgressText'
$StatusText = Find-Control 'StatusText'
$SimpleResultsList = Find-Control 'SimpleResultsList'
$StartButton = Find-Control 'StartButton'
$StopButton = Find-Control 'StopButton'
$GenerateReportsButton = Find-Control 'GenerateReportsButton'
$OpenCsvButton = Find-Control 'OpenCsvButton'
$RunAsAdminButton = Find-Control 'RunAsAdminButton'
$CompareCsvAText = Find-Control 'CompareCsvAText'
$BrowseCompareAButton = Find-Control 'BrowseCompareAButton'
$CompareCsvBText = Find-Control 'CompareCsvBText'
$BrowseCompareBButton = Find-Control 'BrowseCompareBButton'
$CompareOfflineRadio = Find-Control 'CompareOfflineRadio'
$CompareOnlineRadio = Find-Control 'CompareOnlineRadio'
$GenerateComparisonButton = Find-Control 'GenerateComparisonButton'
$HeaderBorder = Find-Control 'HeaderBorder'
$DarkModeCheck = Find-Control 'DarkModeCheck'
$MainTabControl = Find-Control 'MainTabControl'
$ScanActionButtons = Find-Control 'ScanActionButtons'
$CompareActionButtons = Find-Control 'CompareActionButtons'

$script:LastCompletedScanCsv = ''
$script:IsDarkModeEnabled = $false
$script:CurrentRunPartialResults = @{}
$script:CurrentRunPartialOrder = [System.Collections.Generic.List[string]]::new()
$script:NoMatchingEndpointsNotified = $false
$script:HasCompletedScanInSession = $false
$script:CurrentRunStartedAt = $null
$script:DisabledScanOutputHint = 'These buttons are disabled until you ran a successful scan'
$script:GenerateReportsButtonDefaultToolTip = [string]$GenerateReportsButton.ToolTip
$script:OpenCsvButtonDefaultToolTip = [string]$OpenCsvButton.ToolTip
$script:DefaultWindowWidth = 1280
$script:DefaultWindowHeight = 860

# Tracks the ListBoxItem in SimpleResultsList for each "url:port" key so we
# can flip its status indicator (gold -> green/red) when results arrive.
$script:SimpleResultRows = @{}

function Set-OutputView {
    param([Parameter(Mandatory)][bool]$ShowDetailed)
    if ($ShowDetailed) {
        $StatusText.Visibility = 'Visible'
        $SimpleResultsList.Visibility = 'Collapsed'
    } else {
        $StatusText.Visibility = 'Collapsed'
        $SimpleResultsList.Visibility = 'Visible'
    }
}

function Initialize-INRWindowSizeFromSettings {
    $screenWidth = [int][Math]::Floor([System.Windows.SystemParameters]::PrimaryScreenWidth)
    $screenHeight = [int][Math]::Floor([System.Windows.SystemParameters]::PrimaryScreenHeight)

    $savedWidth = 0
    $savedHeight = 0
    $hasSavedWidth = [int]::TryParse([string]$settings.WindowWidth, [ref]$savedWidth)
    $hasSavedHeight = [int]::TryParse([string]$settings.WindowHeight, [ref]$savedHeight)

    $targetWidth = $script:DefaultWindowWidth
    $targetHeight = $script:DefaultWindowHeight
    if ($hasSavedWidth -and $hasSavedHeight -and $savedWidth -gt 0 -and $savedHeight -gt 0 -and $savedWidth -le $screenWidth -and $savedHeight -le $screenHeight) {
        $targetWidth = $savedWidth
        $targetHeight = $savedHeight
    }

    if ($targetWidth -gt $screenWidth) {
        $targetWidth = $screenWidth
    }
    if ($targetHeight -gt $screenHeight) {
        $targetHeight = $screenHeight
    }

    $window.Width = [double]$targetWidth
    $window.Height = [double]$targetHeight
}

function Reset-INRWindowSizeToDefault {
    $screenWidth = [int][Math]::Floor([System.Windows.SystemParameters]::PrimaryScreenWidth)
    $screenHeight = [int][Math]::Floor([System.Windows.SystemParameters]::PrimaryScreenHeight)

    $targetWidth = $script:DefaultWindowWidth
    $targetHeight = $script:DefaultWindowHeight
    if ($targetWidth -gt $screenWidth) {
        $targetWidth = $screenWidth
    }
    if ($targetHeight -gt $screenHeight) {
        $targetHeight = $screenHeight
    }

    if ($window.WindowState -ne [System.Windows.WindowState]::Normal) {
        $window.WindowState = [System.Windows.WindowState]::Normal
    }

    $window.Width = [double]$targetWidth
    $window.Height = [double]$targetHeight
    $window.UpdateLayout()
}

function Update-DarkModeButtonVisual {
    if ($null -eq $DarkModeCheck) { return }

    if ($script:IsDarkModeEnabled) {
        $DarkModeCheck.Content = [char]0x263D
        $DarkModeCheck.ToolTip = 'Switch to light mode'
    } else {
        $DarkModeCheck.Content = [char]0x2600
        $DarkModeCheck.ToolTip = 'Switch to dark mode'
    }
}

function Set-INRBrushResource {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][byte]$R,
        [Parameter(Mandatory)][byte]$G,
        [Parameter(Mandatory)][byte]$B
    )

    if ($null -eq $window -or $null -eq $window.Resources) {
        return
    }

    $brush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb($R, $G, $B))
    $window.Resources[$Key] = $brush
}

function Update-INRAsaListThemeResources {
    param([Parameter(Mandatory)][bool]$DarkMode)

    if ($DarkMode) {
        Set-INRBrushResource -Key 'AsaListBackgroundBrush' -R 45 -G 49 -B 55
        Set-INRBrushResource -Key 'AsaListBorderBrush' -R 88 -G 96 -B 110
        Set-INRBrushResource -Key 'AsaListForegroundBrush' -R 255 -G 255 -B 255
        Set-INRBrushResource -Key 'AsaListItemBackgroundBrush' -R 45 -G 49 -B 55
        Set-INRBrushResource -Key 'AsaListItemHoverBrush' -R 58 -G 63 -B 71
        Set-INRBrushResource -Key 'AsaListItemSelectedBrush' -R 28 -G 79 -B 128
        Set-INRBrushResource -Key 'AsaListItemSelectedInactiveBrush' -R 56 -G 69 -B 84
        Set-INRBrushResource -Key 'AsaListItemSelectedForegroundBrush' -R 255 -G 255 -B 255
    } else {
        Set-INRBrushResource -Key 'AsaListBackgroundBrush' -R 255 -G 255 -B 255
        Set-INRBrushResource -Key 'AsaListBorderBrush' -R 159 -G 199 -B 233
        Set-INRBrushResource -Key 'AsaListForegroundBrush' -R 23 -G 50 -B 77
        Set-INRBrushResource -Key 'AsaListItemBackgroundBrush' -R 255 -G 255 -B 255
        Set-INRBrushResource -Key 'AsaListItemHoverBrush' -R 234 -G 245 -B 255
        Set-INRBrushResource -Key 'AsaListItemSelectedBrush' -R 207 -G 233 -B 255
        Set-INRBrushResource -Key 'AsaListItemSelectedInactiveBrush' -R 220 -G 238 -B 255
        Set-INRBrushResource -Key 'AsaListItemSelectedForegroundBrush' -R 14 -G 62 -B 105
    }
}

function Test-INRVisualAncestorType {
    param(
        [Parameter(Mandatory)][System.Windows.DependencyObject]$Element,
        [Parameter(Mandatory)][type]$AncestorType
    )

    $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($Element)
    while ($null -ne $parent) {
        if ($AncestorType.IsInstanceOfType($parent)) {
            return $true
        }
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
    }
    return $false
}

function Set-CurrentTheme {
    Set-INRTheme -DarkMode $script:IsDarkModeEnabled
    if ($null -ne $window -and $null -ne $window.Dispatcher) {
        $null = $window.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Loaded,
            [action]{ Set-INRTheme -DarkMode $script:IsDarkModeEnabled }
        )
    }
}

function Set-ActionButtonsForSelectedTab {
    $showCompare = $false
    if ($null -ne $MainTabControl -and $null -ne $MainTabControl.SelectedItem) {
        $selectedTab = $MainTabControl.SelectedItem -as [System.Windows.Controls.TabItem]
        if ($selectedTab -and [string]$selectedTab.Header -eq 'Compare Runs') {
            $showCompare = $true
        }
    }

    if ($null -ne $ScanActionButtons) {
        $ScanActionButtons.Visibility = if ($showCompare) { 'Collapsed' } else { 'Visible' }
    }
    if ($null -ne $CompareActionButtons) {
        $CompareActionButtons.Visibility = if ($showCompare) { 'Visible' } else { 'Collapsed' }
    }
}

function Clear-SimpleResults {
    $SimpleResultsList.Items.Clear()
    $script:SimpleResultRows = @{}
}

function Show-NoMatchingEndpointsPopup {
    if ($script:NoMatchingEndpointsNotified) {
        return
    }

    $script:NoMatchingEndpointsNotified = $true
    [System.Windows.MessageBox]::Show('No matching endpoints found in the custom ASA, MSJSON or M365JSON', 'No Matching Endpoints', 'OK', 'Warning') | Out-Null
}

function Update-ScanOutputActionButtons {
    $hasCompletedScanResult = (
        $script:HasCompletedScanInSession -and
        -not [string]::IsNullOrWhiteSpace($script:LastCompletedScanCsv) -and
        (Test-Path -LiteralPath $script:LastCompletedScanCsv)
    )

    if ($null -ne $GenerateReportsButton) {
        $GenerateReportsButton.IsEnabled = $hasCompletedScanResult
        $GenerateReportsButton.Opacity = if ($hasCompletedScanResult) { 1.0 } else { 0.55 }
        $GenerateReportsButton.Cursor = if ($hasCompletedScanResult) { 'Hand' } else { 'No' }
        $GenerateReportsButton.ToolTip = if ($hasCompletedScanResult) { $script:GenerateReportsButtonDefaultToolTip } else { $script:DisabledScanOutputHint }
    }
    if ($null -ne $OpenCsvButton) {
        $OpenCsvButton.IsEnabled = $hasCompletedScanResult
        $OpenCsvButton.Opacity = if ($hasCompletedScanResult) { 1.0 } else { 0.55 }
        $OpenCsvButton.Cursor = if ($hasCompletedScanResult) { 'Hand' } else { 'No' }
        $OpenCsvButton.ToolTip = if ($hasCompletedScanResult) { $script:OpenCsvButtonDefaultToolTip } else { $script:DisabledScanOutputHint }
    }
}

function Get-INRExcelExecutablePath {
    $excelCmd = Get-Command -Name 'excel.exe' -ErrorAction SilentlyContinue
    if ($null -ne $excelCmd -and -not [string]::IsNullOrWhiteSpace($excelCmd.Path) -and (Test-Path -LiteralPath $excelCmd.Path)) {
        return [string]$excelCmd.Path
    }

    $appPathKeys = @(
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe',
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\excel.exe',
        'Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe'
    )

    foreach ($keyPath in $appPathKeys) {
        try {
            $key = Get-Item -LiteralPath $keyPath -ErrorAction Stop
            $candidate = [string]$key.GetValue('')
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
                return $candidate
            }
        } catch {
            continue
        }
    }

    return $null
}

function Update-PartialScanResultFromLine {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return
    }

    if ($Line -notmatch 'C:TestNetwork\s+M:TestNetworkResult:\s+(\S+?):(\S+)\s+DNS=(\S+)\s+TCP=(\S+)\s+SSL=(\S+)') {
        return
    }

    $url = $matches[1]
    $port = $matches[2]
    $key = "$url`:$port"

    if (-not $script:CurrentRunPartialResults.ContainsKey($key)) {
        [void]$script:CurrentRunPartialOrder.Add($key)
        $script:CurrentRunPartialResults[$key] = [pscustomobject]@{
            id = [string]$script:CurrentRunPartialOrder.Count
            url = $url
            Port = $port
            DNSResult = ''
            TCPResult = ''
            SSLTest = ''
        }
    }

    $record = $script:CurrentRunPartialResults[$key]
    $record.DNSResult = $matches[3]
    $record.TCPResult = $matches[4]
    $record.SSLTest = $matches[5]
}

function Update-RunOutputLineState {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return
    }

    # Simple traffic-light view: one row per "url:port".
    if ($Line -match 'C:TestNetwork\s+M:Testing\s+(\S+)\s+on port\s+(\S+)') {
        Set-SimpleResultStatus -Url $matches[1] -Port $matches[2] -Status 'InProgress'
        return
    }

    if ($Line -match 'C:TestNetwork\s+M:TestNetworkResult:\s+(\S+?):(\S+)\s+DNS=(\S+)\s+TCP=(\S+)\s+SSL=(\S+)') {
        Update-PartialScanResultFromLine -Line $Line

        # Endpoint is "good" if TCP succeeded, or (UDP/skipped TCP)
        # if DNS succeeded. SSL outcome is intentionally not part of
        # the dot so a working endpoint with a cert quirk stays green.
        $tcpOk = ($matches[4] -eq 'True')
        $dnsOk = ($matches[3] -eq 'True')
        $tcpMissing = [string]::IsNullOrWhiteSpace($matches[4])
        if ($tcpOk -or ($dnsOk -and $tcpMissing)) {
            Set-SimpleResultStatus -Url $matches[1] -Port $matches[2] -Status 'Ok'
        } else {
            Set-SimpleResultStatus -Url $matches[1] -Port $matches[2] -Status 'Failed'
        }
    }
}

function Save-PartialScanCsv {
    if ($script:CurrentRunPartialOrder.Count -eq 0) {
        return $null
    }

    $testResultsPath = Join-Path -Path $RootPath -ChildPath 'TestResults'
    if (-not (Test-Path -LiteralPath $testResultsPath)) {
        New-Item -ItemType Directory -Path $testResultsPath -Force | Out-Null
    }

    $computerName = $env:COMPUTERNAME
    if ([string]::IsNullOrWhiteSpace($computerName)) {
        $computerName = 'UnknownHost'
    }
    $partialCsvPath = Join-Path -Path $testResultsPath -ChildPath ("ResultList_partial_{0}_{1}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $computerName)

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($key in $script:CurrentRunPartialOrder) {
        $record = $script:CurrentRunPartialResults[$key]
        $rows.Add([pscustomobject][ordered]@{
            id = $record.id
            url = $record.url
            Port = $record.Port
            Protocol = ''
            required = ''
            DNSResult = $record.DNSResult
            TCPResult = $record.TCPResult
            HTTPStatusCode = ''
            SSLTest = $record.SSLTest
            SSLProtocol = ''
            Issuer = ''
            AuthException = ''
            KnownCRL = ''
            SSLInterception = ''
        }) | Out-Null
    }

    $rows | Export-Csv -LiteralPath $partialCsvPath -NoTypeInformation
    return $partialCsvPath
}

$script:ProgressPercent = 0.0
function Set-ProgressBarVisual {
    param([Parameter(Mandatory)][double]$Percent)

    $clampedPercent = [Math]::Max(0, [Math]::Min(100, $Percent))
    $script:ProgressPercent = $clampedPercent

    $hostWidth = [Math]::Max(0, $RainbowProgressHost.ActualWidth - 2)
    if ($hostWidth -le 0) {
        return
    }

    $RainbowProgressFill.Width = $hostWidth
    $RainbowProgressMask.Width = $hostWidth * ((100 - $clampedPercent) / 100)
}

function Add-SimpleResultEntry {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Port
    )
    $key = "$Url`:$Port"
    if ($script:SimpleResultRows.ContainsKey($key)) { return $script:SimpleResultRows[$key] }

    $item = New-Object System.Windows.Controls.ListBoxItem
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Orientation = 'Horizontal'
    $ellipse = New-Object System.Windows.Shapes.Ellipse
    $ellipse.Width = 12; $ellipse.Height = 12
    $ellipse.Margin = '0,0,8,0'
    $ellipse.Fill = [System.Windows.Media.Brushes]::Gold
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $key
    $text.VerticalAlignment = 'Center'
    [void]$panel.Children.Add($ellipse)
    [void]$panel.Children.Add($text)
    $item.Content = $panel
    $item.Tag = $ellipse
    [void]$SimpleResultsList.Items.Add($item)
    $script:SimpleResultRows[$key] = $item
    return $item
}

function Set-SimpleResultStatus {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Port,
        [Parameter(Mandatory)][ValidateSet('Pending','InProgress','Ok','Failed')][string]$Status
    )
    $key = "$Url`:$Port"
    if (-not $script:SimpleResultRows.ContainsKey($key)) {
        Add-SimpleResultEntry -Url $Url -Port $Port | Out-Null
    }
    $item = $script:SimpleResultRows[$key]
    $ellipse = $item.Tag
    switch ($Status) {
        'Pending'    { $ellipse.Fill = [System.Windows.Media.Brushes]::Gray }
        'InProgress' { $ellipse.Fill = [System.Windows.Media.Brushes]::Gold }
        'Ok'         { $ellipse.Fill = [System.Windows.Media.Brushes]::ForestGreen }
        'Failed'     { $ellipse.Fill = [System.Windows.Media.Brushes]::Crimson }
    }
}

$UseCustomCsvCheck.IsChecked = [bool]$settings.UseCustomCsv
$CustomCsvPathText.Text = [string]$settings.CustomCsvPath
$UseMSJsonCheck.IsChecked = [bool]$settings.UseMSJSON
$UseMS365JsonCheck.IsChecked = [bool]$settings.UseMS365JSON
$AllowBestEffortCheck.IsChecked = [bool]$settings.AllowBestEffort
$CheckCertRevocationCheck.IsChecked = [bool]$settings.CheckCertRevocation
$DetailedOutputCheck.IsChecked = [bool]$settings.DetailedOutput
Set-OutputView -ShowDetailed:([bool]$settings.DetailedOutput)
$DetailedOutputCheck.Add_Click({
    if (-not [bool]$DetailedOutputCheck.IsEnabled) { return }
    Set-OutputView -ShowDetailed:([bool]$DetailedOutputCheck.IsChecked)
})
$EnableLogFileCheck.IsChecked = [bool]$settings.EnableLogFile
$OpenCsvWithDefaultProgramCheck.IsChecked = [bool]$settings.OpenCsvWithDefaultProgram
$TenantNameText.Text = [string]$settings.TenantName
$MaxDelayText.Text = [string]$settings.MaxDelayInMS
$BurstModeCheck.IsChecked = [bool]$settings.BurstMode
$script:IsDarkModeEnabled = [bool]$settings.DarkMode
Update-DarkModeButtonVisual
$CompareCsvAText.Text = [string]$settings.CompareCsvA
$CompareCsvBText.Text = [string]$settings.CompareCsvB
if ([string]$settings.CompareAssetMode -eq 'Online') {
    $CompareOnlineRadio.IsChecked = $true
} else {
    $CompareOfflineRadio.IsChecked = $true
}

Initialize-INRWindowSizeFromSettings

$availableAsas = Get-INRAvailableASAs
foreach ($asa in $availableAsas) { [void]$AsaList.Items.Add($asa) }
if ($settings.SelectedASAs) {
    foreach ($selected in $settings.SelectedASAs) {
        $idx = $AsaList.Items.IndexOf($selected)
        if ($idx -ge 0) { $AsaList.SelectedItems.Add($AsaList.Items[$idx]) | Out-Null }
    }
}

if ($AsaList.SelectedItems.Count -eq 0) {
    $idx = $AsaList.Items.IndexOf('Intune')
    if ($idx -ge 0) { $AsaList.SelectedItems.Add($AsaList.Items[$idx]) | Out-Null }
}

Update-ScanOutputActionButtons

$pollTimer = New-Object Windows.Threading.DispatcherTimer
$pollTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$pollTimer.Add_Tick({
    try {
        $status = Get-INRRunStatus
        $lines = @(Get-INRNewOutput)

        if ($lines.Count -gt 0) {
            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace([string]$line)) {
                    continue
                }

                # Always buffer to the detailed view so toggling Detailed Output
                # later reveals the full history, not just lines since the toggle.
                $StatusText.AppendText($line + [Environment]::NewLine)
                Update-RunOutputLineState -Line ([string]$line)
            }
            $StatusText.ScrollToEnd()
        }

        $completed = $status.CurrentAsaCompleted
        $total = $status.CurrentAsaTotal
        $pct = if ($total -gt 0) { [Math]::Min(100, [math]::Round(($completed / $total) * 100, 2)) } else { 0 }
        Set-ProgressBarVisual -Percent $pct
        $eta = Get-INREta

        $main = if ($status.MainAsa) { $status.MainAsa } else { '...' }
        $cur = if ($status.CurrentAsa) { $status.CurrentAsa } else { '...' }
        $mainCount = $status.MainAsaCount
        $remaining = $status.RemainingMainAsaCount
        $done = $mainCount - $remaining
        if ($done -lt 0) { $done = 0 }
        $totalText = if ($total -gt 0) { "$total" } else { '?' }

        if ($main -eq $cur) {
            $asaText = "ASA: $main"
        } else {
            $asaText = "ASA: $main > $cur"
        }
        $ProgressText.Text = "$asaText | Main $done/$mainCount (remaining $remaining) | URLs $completed/$totalText | ETA $eta"

        if (-not $status.IsRunning -and $status.ProcessId) {
            $StartButton.IsEnabled = $true
            $scanResultsFolder = Join-Path -Path $RootPath -ChildPath 'TestResults'
            $script:HasCompletedScanInSession = $false
            $script:LastCompletedScanCsv = ''
            if (Test-Path -LiteralPath $scanResultsFolder) {
                $latestScanCsv = Get-ChildItem -LiteralPath $scanResultsFolder -Filter 'ResultList*.csv' -File |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
                if ($latestScanCsv) {
                    $resultIsFromCurrentRun = $true
                    if ($null -ne $script:CurrentRunStartedAt) {
                        $resultIsFromCurrentRun = ($latestScanCsv.LastWriteTime -ge $script:CurrentRunStartedAt)
                    }

                    if ($resultIsFromCurrentRun) {
                        $script:LastCompletedScanCsv = $latestScanCsv.FullName
                        $script:HasCompletedScanInSession = $true
                    }
                }
            }
            $StatusText.AppendText('Execution finished.' + [Environment]::NewLine)
            $finalMain = if ($status.MainAsa) { $status.MainAsa } else { '-' }
            $finalTotal = if ($status.CurrentAsaTotal -gt 0) { "$($status.CurrentAsaTotal)" } else { "$($status.CurrentAsaCompleted)" }
            $ProgressText.Text = "Done | ASA: $finalMain | URLs $($status.CurrentAsaCompleted)/$finalTotal | ETA 00:00:00"

            if ($status.CurrentAsaCompleted -eq 0 -and $status.CurrentAsaTotal -eq 0 -and $script:CurrentRunPartialOrder.Count -eq 0) {
                Show-NoMatchingEndpointsPopup
                $StatusText.AppendText('No matching endpoints found in the selected sources for the selected ASA(s).' + [Environment]::NewLine)
                $script:HasCompletedScanInSession = $false
                $script:LastCompletedScanCsv = ''
            }

            Update-ScanOutputActionButtons
            $script:CurrentRunStartedAt = $null
            Set-ProgressBarVisual -Percent 0
            $pollTimer.Stop()
        }
    } catch {
        $msg = $_.Exception.Message
        if ($msg -like "*Cannot bind argument to parameter 'Line' because it is an empty string.*") {
            Show-NoMatchingEndpointsPopup
            $StatusText.AppendText('No matching endpoints found in the selected sources for the selected ASA(s).' + [Environment]::NewLine)
        } else {
            $StatusText.AppendText("Runtime warning: $msg" + [Environment]::NewLine)
        }

        try { $pollTimer.Stop() } catch { }
        $StartButton.IsEnabled = $true
        Set-ProgressBarVisual -Percent 0
        $ProgressText.Text = 'Progress: stopped | ETA: -'
        $script:HasCompletedScanInSession = $false
        $script:LastCompletedScanCsv = ''
        $script:CurrentRunStartedAt = $null
        Update-ScanOutputActionButtons
        try { Update-INRContextStatus -RootPath $RootPath -Status 'stopped' } catch { }
    }
})

function Get-SelectedAsas {
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $AsaList.SelectedItems) { $list.Add([string]$item) }
    return $list.ToArray()
}

function Update-OverlapWarnings {
    $selectedAsas = Get-SelectedAsas
    $warnings = Get-INROverlapWarnings -SelectedASAs $selectedAsas
    $rule = Test-INRAdditionalAsaRules -SelectedASAs $selectedAsas -UseMSJSON ([bool]$UseMSJsonCheck.IsChecked) -UseMS365JSON ([bool]$UseMS365JsonCheck.IsChecked) -UseCustomCsv ([bool]$UseCustomCsvCheck.IsChecked)

    if ($rule.HasAdditionalASAs) {
        $UseMSJsonCheck.IsChecked = $false
        $UseMS365JsonCheck.IsChecked = $false
        $UseMSJsonCheck.IsEnabled = $false
        $UseMS365JsonCheck.IsEnabled = $false
        $UseCustomCsvCheck.IsChecked = $true
        $warnings = @($warnings + $rule.Message)
    } else {
        $UseMSJsonCheck.IsEnabled = $true
        $UseMS365JsonCheck.IsEnabled = $true
    }

    $OverlapWarningText.Text = ($warnings -join [Environment]::NewLine)
}

function Save-UiSettings {
    $selectedAsas = Get-SelectedAsas

    # Parse defensively: Save-UiSettings also runs on window close, where a
    # non-numeric MaxDelay must not throw and abort the shutdown save.
    $maxDelay = 300
    if (-not [int]::TryParse([string]$MaxDelayText.Text, [ref]$maxDelay)) {
        $maxDelay = 300
    }

    $widthRaw = if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        [double]$window.RestoreBounds.Width
    } else {
        [double]$window.Width
    }
    $heightRaw = if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        [double]$window.RestoreBounds.Height
    } else {
        [double]$window.Height
    }

    $windowWidthToSave = if ([double]::IsNaN($widthRaw) -or [double]::IsInfinity($widthRaw) -or $widthRaw -le 0) {
        $script:DefaultWindowWidth
    } else {
        [int][Math]::Round($widthRaw)
    }
    $windowHeightToSave = if ([double]::IsNaN($heightRaw) -or [double]::IsInfinity($heightRaw) -or $heightRaw -le 0) {
        $script:DefaultWindowHeight
    } else {
        [int][Math]::Round($heightRaw)
    }

    $toSave = [pscustomobject]@{
        UseCustomCsv = [bool]$UseCustomCsvCheck.IsChecked
        CustomCsvPath = $CustomCsvPathText.Text
        UseMSJSON = [bool]$UseMSJsonCheck.IsChecked
        UseMS365JSON = [bool]$UseMS365JsonCheck.IsChecked
        AllowBestEffort = [bool]$AllowBestEffortCheck.IsChecked
        CheckCertRevocation = [bool]$CheckCertRevocationCheck.IsChecked
        EnableLogFile = [bool]$EnableLogFileCheck.IsChecked
        TenantName = $TenantNameText.Text
        MaxDelayInMS = $maxDelay
        BurstMode = [bool]$BurstModeCheck.IsChecked
        DetailedOutput = [bool]$DetailedOutputCheck.IsChecked
        OpenCsvWithDefaultProgram = [bool]$OpenCsvWithDefaultProgramCheck.IsChecked
        DarkMode = [bool]$script:IsDarkModeEnabled
        SelectedASAs = $selectedAsas
        CompareCsvA = $CompareCsvAText.Text
        CompareCsvB = $CompareCsvBText.Text
        CompareAssetMode = if ([bool]$CompareOnlineRadio.IsChecked) { 'Online' } else { 'Offline' }
        WindowWidth = $windowWidthToSave
        WindowHeight = $windowHeightToSave
    }
    Export-INRSettings -RootPath $RootPath -Settings $toSave
    return $toSave
}

function Set-INRTheme {
    param(
        [bool]$DarkMode
    )

    if ($DarkMode) {
        $window.Background = [System.Windows.Media.Brushes]::Black
        $HeaderBorder.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(20, 54, 87))
        $panelBackground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(32, 34, 37))
        $inputBackground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(45, 49, 55))
        $textBrush = [System.Windows.Media.Brushes]::White
        $borderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(88, 96, 110))
    } else {
        $window.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(244, 251, 255))
        $HeaderBorder.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(15, 108, 189))
        $panelBackground = [System.Windows.Media.Brushes]::White
        $inputBackground = [System.Windows.Media.Brushes]::White
        $textBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(23, 50, 77))
        $borderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(159, 199, 233))
    }

    Update-INRAsaListThemeResources -DarkMode $DarkMode

    $controlQueue = [System.Collections.Generic.Queue[System.Windows.DependencyObject]]::new()
    $controlQueue.Enqueue($window)
    while ($controlQueue.Count -gt 0) {
        $node = $controlQueue.Dequeue()
        $childCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($node)
        for ($i = 0; $i -lt $childCount; $i++) {
            $child = [System.Windows.Media.VisualTreeHelper]::GetChild($node, $i)
            $controlQueue.Enqueue($child)

            if ($child -is [System.Windows.Controls.Border]) {
                if (Test-INRVisualAncestorType -Element $child -AncestorType ([System.Windows.Controls.ListBoxItem])) {
                    continue
                }
                if ($child.Name -ne 'HeaderBorder' -and $child.Name -ne 'RainbowProgressHost') {
                    $child.Background = $panelBackground
                }
                if ($child.Name -eq 'RainbowProgressHost') {
                    if ($DarkMode) {
                        $child.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(28, 33, 40))
                    } else {
                        $child.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(234, 245, 255))
                    }
                }
                $child.BorderBrush = $borderBrush
            }
            if ($child -is [System.Windows.Controls.TextBlock]) {
                if (Test-INRVisualAncestorType -Element $child -AncestorType ([System.Windows.Controls.ListBoxItem])) {
                    continue
                }
                if ($child.Text -notlike 'INR With GUI*') {
                    $child.Foreground = $textBrush
                }
            }
            if ($child -is [System.Windows.Controls.TextBox] -or $child -is [System.Windows.Controls.ComboBox] -or $child -is [System.Windows.Controls.ListBox]) {
                if ($child -is [System.Windows.Controls.ListBox] -and $child.Name -eq 'AsaList') {
                    continue
                }
                $child.Background = $inputBackground
                $child.Foreground = $textBrush
            }
            if ($child -is [System.Windows.Controls.Button]) {
                $child.Foreground = $textBrush
                if ($child.Name -eq 'DarkModeCheck') {
                    $child.Background = $inputBackground
                    $child.BorderBrush = $borderBrush
                }
            }
            if ($child -is [System.Windows.Controls.Primitives.ToggleButton]) {
                $child.Background = $inputBackground
                $child.BorderBrush = $borderBrush
                $child.Foreground = $textBrush
            }
            if ($child -is [System.Windows.Controls.CheckBox] -or $child -is [System.Windows.Controls.RadioButton]) {
                $child.Background = $inputBackground
                $child.BorderBrush = $borderBrush
                $child.Foreground = $textBrush
            }
        }
    }
}

$UseCustomCsvCheck.Add_Click({
    $enabled = [bool]$UseCustomCsvCheck.IsChecked
    $CustomCsvPathText.IsEnabled = $enabled
    $BrowseCustomCsvButton.IsEnabled = $enabled
    Update-OverlapWarnings
})
$UseMSJsonCheck.Add_Click({ Update-OverlapWarnings })
$UseMS365JsonCheck.Add_Click({ Update-OverlapWarnings })
$AsaList.Add_SelectionChanged({ Update-OverlapWarnings })
$DarkModeCheck.Add_Click({
    $script:IsDarkModeEnabled = -not $script:IsDarkModeEnabled
    Update-DarkModeButtonVisual
    Set-CurrentTheme
})

$ResetWindowSizeButton.Add_Click({
    try {
        Reset-INRWindowSizeToDefault
        Save-UiSettings | Out-Null
        $StatusText.AppendText("Window size reset to default: $([int]$window.Width)x$([int]$window.Height)." + [Environment]::NewLine)
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Reset Window Size failed', 'OK', 'Error') | Out-Null
    }
})

$BrowseCustomCsvButton.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'CSV files (*.csv)|*.csv'
    $dlg.Multiselect = $false
    if ($dlg.ShowDialog()) {
        $result = Test-INRCustomCsvFormat -CsvPath $dlg.FileName
        if ($result.IsValid) {
            $CustomCsvPathText.Text = $dlg.FileName
            $StatusText.AppendText("Custom CSV validated: $($dlg.FileName)" + [Environment]::NewLine)
        } else {
            [System.Windows.MessageBox]::Show($result.Message, 'Invalid CSV', 'OK', 'Warning') | Out-Null
        }
    }
})

$StartButton.Add_Click({
    try {
        $saved = Save-UiSettings

        if ($saved.UseCustomCsv) {
            $validation = Test-INRCustomCsvFormat -CsvPath $saved.CustomCsvPath
            if (-not $validation.IsValid) {
                [System.Windows.MessageBox]::Show($validation.Message, 'CSV Validation', 'OK', 'Error') | Out-Null
                return
            }
        }

        [void](Start-INRRun -RootPath $RootPath -Settings $saved)

        $StartButton.IsEnabled = $false
        $script:HasCompletedScanInSession = $false
        $script:LastCompletedScanCsv = ''
        $script:CurrentRunStartedAt = Get-Date
        Update-ScanOutputActionButtons
        $StatusText.Clear()
        Clear-SimpleResults
        $script:CurrentRunPartialResults = @{}
        $script:CurrentRunPartialOrder = [System.Collections.Generic.List[string]]::new()
        $script:NoMatchingEndpointsNotified = $false
        Set-ProgressBarVisual -Percent 0
        $StatusText.AppendText('Execution started.' + [Environment]::NewLine)
        $pollTimer.Start()

        Update-INRContextStatus -RootPath $RootPath -Status 'running'
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Start failed', 'OK', 'Error') | Out-Null
    }
})

$StopButton.Add_Click({
    try {
        $stopResult = Stop-INRRun -Reason 'User requested stop via GUI'
        if (-not $stopResult.WasRunning) {
            $StatusText.AppendText('Stop requested but no run was active.' + [Environment]::NewLine)
        } else {
            $remainingLines = @(Get-INRNewOutput)
            foreach ($line in $remainingLines) {
                $StatusText.AppendText($line + [Environment]::NewLine)
                Update-RunOutputLineState -Line $line
            }

            $partialCsvPath = Save-PartialScanCsv

            switch ($stopResult.Method) {
                'graceful'     { $StatusText.AppendText("Run stopped gracefully (exit code: $($stopResult.ExitCode))." + [Environment]::NewLine) }
                'killed'       { $StatusText.AppendText("Run terminated by user (exit code: $($stopResult.ExitCode))." + [Environment]::NewLine) }
                'kill-timeout' { $StatusText.AppendText('Stop requested but child process did not exit within timeout.' + [Environment]::NewLine) }
                default        { $StatusText.AppendText('Stop requested.' + [Environment]::NewLine) }
            }
            if ($partialCsvPath) {
                $script:LastCompletedScanCsv = $partialCsvPath
                $StatusText.AppendText("Partial scan result saved: $partialCsvPath" + [Environment]::NewLine)
            } else {
                $StatusText.AppendText('No endpoint results were captured before stop; partial CSV was not created.' + [Environment]::NewLine)
            }
            if ($stopResult.LogFilePath) {
                $StatusText.AppendText("Stop reason written to log: $($stopResult.LogFilePath)" + [Environment]::NewLine)
            }
            if ($stopResult.Error) {
                $StatusText.AppendText("Stop warning: $($stopResult.Error)" + [Environment]::NewLine)
            }
        }
    } catch {
        $StatusText.AppendText("Stop failed: $($_.Exception.Message)" + [Environment]::NewLine)
    } finally {
        try { $pollTimer.Stop() } catch { }
        try { Reset-INRRunState } catch { }
        Set-ProgressBarVisual -Percent 0
        $ProgressText.Text = 'Progress: stopped | ETA: -'
        $StartButton.IsEnabled = $true
        $script:HasCompletedScanInSession = $false
        $script:LastCompletedScanCsv = ''
        $script:CurrentRunStartedAt = $null
        Update-ScanOutputActionButtons
        Update-INRContextStatus -RootPath $RootPath -Status 'stopped'
    }
})

$GenerateReportsButton.Add_Click({
    try {
        if (-not $GenerateReportsButton.IsEnabled) {
            [System.Windows.MessageBox]::Show('Run a scan to completion before generating a scan report.', 'Generate Scan Report', 'OK', 'Information') | Out-Null
            return
        }

        $scanCsvForReport = $null
        if ($script:LastCompletedScanCsv -and (Test-Path -LiteralPath $script:LastCompletedScanCsv)) {
            $scanCsvForReport = $script:LastCompletedScanCsv
        } else {
            [System.Windows.MessageBox]::Show('You have not run a scan yet, please select a file', 'Select Scan Result CSV', 'OK', 'Information') | Out-Null
            $csvDialog = New-Object Microsoft.Win32.OpenFileDialog
            $csvDialog.Filter = 'Result CSV files (*.csv)|*.csv'
            $csvDialog.Multiselect = $false
            if ($csvDialog.ShowDialog()) {
                $scanCsvForReport = $csvDialog.FileName
            } else {
                return
            }
        }

        if ($scanCsvForReport) {
            $scanReport = Join-Path $RootPath ("Reports\ScanReport_{0}.html" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
            $selectedAsas = Get-SelectedAsas
            $path = New-INRMindMapReport -CsvPath $scanCsvForReport -OutputHtmlPath $scanReport -SelectedASAs $selectedAsas
            $StatusText.AppendText("Scan report created: $path" + [Environment]::NewLine)
            try { Start-Process -FilePath $path | Out-Null } catch { $StatusText.AppendText("Could not open report: $($_.Exception.Message)" + [Environment]::NewLine) }
        }
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Report generation failed', 'OK', 'Error') | Out-Null
    }
})

$BrowseCompareAButton.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Result CSV files (ResultList*.csv)|ResultList*.csv|All CSV files (*.csv)|*.csv'
    $dlg.InitialDirectory = Join-Path $RootPath 'TestResults'
    $dlg.Multiselect = $false
    if ($dlg.ShowDialog()) { $CompareCsvAText.Text = $dlg.FileName }
})

$BrowseCompareBButton.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Result CSV files (ResultList*.csv)|ResultList*.csv|All CSV files (*.csv)|*.csv'
    $dlg.InitialDirectory = Join-Path $RootPath 'TestResults'
    $dlg.Multiselect = $false
    if ($dlg.ShowDialog()) { $CompareCsvBText.Text = $dlg.FileName }
})

$GenerateComparisonButton.Add_Click({
    try {
        $csvA = $CompareCsvAText.Text
        $csvB = $CompareCsvBText.Text
        if ([string]::IsNullOrWhiteSpace($csvA) -or [string]::IsNullOrWhiteSpace($csvB)) {
            [System.Windows.MessageBox]::Show('Select two result CSV files to compare (Run A and Run B).', 'Compare Runs', 'OK', 'Information') | Out-Null
            return
        }
        if (-not (Test-Path -LiteralPath $csvA)) {
            [System.Windows.MessageBox]::Show("Run A CSV not found:`n$csvA", 'Compare Runs', 'OK', 'Error') | Out-Null
            return
        }
        if (-not (Test-Path -LiteralPath $csvB)) {
            [System.Windows.MessageBox]::Show("Run B CSV not found:`n$csvB", 'Compare Runs', 'OK', 'Error') | Out-Null
            return
        }

        Save-UiSettings | Out-Null
        $assetMode = if ([bool]$CompareOnlineRadio.IsChecked) { 'Online' } else { 'Offline' }
        $comparisonReport = Join-Path $RootPath ("Reports\Comparison_{0}.html" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $path = New-INRComparisonReport -CsvPathA $csvA -CsvPathB $csvB -OutputHtmlPath $comparisonReport -AssetMode $assetMode
        $StatusText.AppendText("Comparison report created ($assetMode): $path" + [Environment]::NewLine)
        try { Start-Process -FilePath $path | Out-Null } catch { $StatusText.AppendText("Could not open report: $($_.Exception.Message)" + [Environment]::NewLine) }
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Comparison report failed', 'OK', 'Error') | Out-Null
    }
})

$OpenCsvButton.Add_Click({
    try {
        if (-not $OpenCsvButton.IsEnabled) {
            [System.Windows.MessageBox]::Show('Run a scan to completion before opening the result CSV.', 'Open CSV', 'OK', 'Information') | Out-Null
            return
        }

        $csvPath = $null
        if ($script:LastCompletedScanCsv -and (Test-Path -LiteralPath $script:LastCompletedScanCsv)) {
            $csvPath = $script:LastCompletedScanCsv
        } else {
            $csvDialog = New-Object Microsoft.Win32.OpenFileDialog
            $csvDialog.Filter = 'Result CSV files (ResultList*.csv)|ResultList*.csv|All CSV files (*.csv)|*.csv'
            $csvDialog.InitialDirectory = Join-Path $RootPath 'TestResults'
            $csvDialog.Multiselect = $false
            if ($csvDialog.ShowDialog()) {
                $csvPath = $csvDialog.FileName
            } else {
                return
            }
        }

        if ([bool]$OpenCsvWithDefaultProgramCheck.IsChecked) {
            try {
                Invoke-Item -LiteralPath $csvPath
            } catch {
                [System.Windows.MessageBox]::Show("Failed to open CSV: $($_.Exception.Message)", 'Open CSV failed', 'OK', 'Error') | Out-Null
            }
            return
        }

        $excelPath = Get-INRExcelExecutablePath
        if (-not [string]::IsNullOrWhiteSpace($excelPath)) {
            try {
                Start-Process -FilePath $excelPath -ArgumentList "`"$csvPath`"" -ErrorAction Stop | Out-Null
                return
            } catch {
                # Fall back to the default .csv handler below if launching
                # Excel failed at runtime despite being present.
            }
        }

        try {
            Invoke-Item -LiteralPath $csvPath
            [System.Windows.MessageBox]::Show("Direct Excel launch was unavailable. Opened the CSV with the default application instead.`n`n$csvPath", 'Opened with default application', 'OK', 'Information') | Out-Null
        } catch {
            [System.Windows.MessageBox]::Show("Failed to open CSV: $($_.Exception.Message)", 'Open CSV failed', 'OK', 'Error') | Out-Null
        }
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Open CSV failed', 'OK', 'Error') | Out-Null
    }
})

$RunAsAdminButton.Add_Click({
    try {
        # Persist current UI state first so the elevated instance starts from
        # the same settings the user is looking at.
        Save-UiSettings | Out-Null

        # Relaunch with the same PowerShell host that is running this window.
        $hostExe = (Get-Process -Id $PID).Path
        if ([string]::IsNullOrWhiteSpace($hostExe)) { $hostExe = 'pwsh.exe' }

        # Quote the script path so it survives spaces in the folder name.
        $launchArgs = @(
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            "`"$($script:ScriptPath)`""
        )
        Start-Process -FilePath $hostExe -ArgumentList $launchArgs -Verb RunAs -ErrorAction Stop

        # Elevation accepted: hand off to the new instance and close this one.
        $window.Close()
    } catch {
        # UAC cancellation surfaces as a Win32Exception (ERROR_CANCELLED = 1223).
        $win32 = $_.Exception -as [System.ComponentModel.Win32Exception]
        if (-not $win32 -and $_.Exception.InnerException) {
            $win32 = $_.Exception.InnerException -as [System.ComponentModel.Win32Exception]
        }
        if ($win32 -and $win32.NativeErrorCode -eq 1223) {
            $StatusText.AppendText('Elevation cancelled - continuing as standard user.' + [Environment]::NewLine)
        } else {
            [System.Windows.MessageBox]::Show("Could not relaunch as administrator: $($_.Exception.Message)", 'Re-run as Administrator', 'OK', 'Error') | Out-Null
        }
    }
})

$CustomCsvPathText.IsEnabled = [bool]$UseCustomCsvCheck.IsChecked
$BrowseCustomCsvButton.IsEnabled = [bool]$UseCustomCsvCheck.IsChecked
Update-OverlapWarnings
Set-ActionButtonsForSelectedTab
if ($null -ne $MainTabControl) {
    $MainTabControl.Add_SelectionChanged({
        if ($_.OriginalSource -ne $MainTabControl) { return }
        Set-ActionButtonsForSelectedTab
        Set-CurrentTheme
    })
}
    Set-CurrentTheme

if (-not $script:IsAdmin) {
    $adminMessage = 'Not running as Administrator. Some network tests (raw sockets, low-port binding, certain certificate checks) may fail or return incomplete results. For full coverage, relaunch PowerShell elevated or use the "Re-run as Administrator" button.'
    $StatusText.AppendText("WARNING: $adminMessage" + [Environment]::NewLine)
    $window.Title = "$($window.Title) - Standard User"
    $RunAsAdminButton.Visibility = 'Visible'
} else {
    $StatusText.AppendText('Running with Administrator privileges.' + [Environment]::NewLine)
}

# Ensure clean shutdown: stop the child process and timers if the window closes
# while a run is active, so the GUI never leaves an orphaned pwsh.exe behind.
$window.Add_Closing({
    try {
        $pollTimer.Stop()
    } catch { }
    try {
        $status = Get-INRRunStatus
        if ($status.IsRunning) {
            [void](Stop-INRRun)
        }
    } catch { }
})

$window.Add_ContentRendered({
    Set-CurrentTheme
    Set-ProgressBarVisual -Percent $script:ProgressPercent
})

$RainbowProgressHost.Add_SizeChanged({
    Set-ProgressBarVisual -Percent $script:ProgressPercent
})

Update-INRContextStatus -RootPath $RootPath -Status 'gui-ready' -AddCompletedPhase 'Phase2-ModuleScaffold'

$null = $window.ShowDialog()

Save-UiSettings | Out-Null
Update-INRContextStatus -RootPath $RootPath -Status 'idle'
