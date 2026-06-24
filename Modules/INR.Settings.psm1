Set-StrictMode -Version Latest

function Get-INRSettingsPath {
    <#
    .SYNOPSIS
    Returns the absolute path to the GUI settings file (Settings.json).
    .PARAMETER RootPath
    Repository root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    return Join-Path -Path $RootPath -ChildPath 'Settings.json'
}

function Get-INRDefaultSettings {
    <#
    .SYNOPSIS
    Returns the default GUI settings as an ordered hashtable.
    #>
    [CmdletBinding()]
    param()

    return [ordered]@{
        UseCustomCsv = $false
        CustomCsvPath = ''
        UseMSJSON = $true
        UseMS365JSON = $false
        AllowBestEffort = $true
        CheckCertRevocation = $true
        EnableLogFile = $true
        TenantName = ''
        MaxDelayInMS = 300
        BurstMode = $false
        DetailedOutput = $true
        OpenCsvWithDefaultProgram = $false
        DarkMode = $false
        SelectedASAs = @('Intune')
        CompareCsvA = ''
        CompareCsvB = ''
        CompareAssetMode = 'Offline'
        WindowWidth = 1280
        WindowHeight = 860
    }
}

function Import-INRSettings {
    <#
    .SYNOPSIS
    Loads Settings.json, creating it from defaults if missing and backing up a
    corrupt file before regenerating it.
    .PARAMETER RootPath
    Repository root.
    .OUTPUTS
    The settings as a [pscustomobject], with any missing keys filled from
    defaults.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $path = Get-INRSettingsPath -RootPath $RootPath
    $defaults = Get-INRDefaultSettings

    if (-not (Test-Path -LiteralPath $path)) {
        $defaults | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
        return [pscustomobject]$defaults
    }

    try {
        $raw = Get-Content -LiteralPath $path -Raw
        $loaded = $raw | ConvertFrom-Json
        # Fill in any keys missing from an older Settings.json. Probe the
        # property bag explicitly: under Set-StrictMode -Version Latest, reading
        # a non-existent property directly (e.g. $loaded.$key) throws, which
        # would wrongly flag a valid file as corrupt whenever defaults add a key.
        foreach ($key in $defaults.Keys) {
            $property = $loaded.PSObject.Properties[$key]
            if ($null -eq $property) {
                $loaded | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key]
            } elseif ($null -eq $property.Value) {
                $property.Value = $defaults[$key]
            }
        }
        return $loaded
    } catch {
        $backupPath = "{0}.corrupt_{1}" -f $path, (Get-Date -Format 'yyyyMMdd_HHmmss')
        Copy-Item -LiteralPath $path -Destination $backupPath -Force
        $defaults | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
        return [pscustomobject]$defaults
    }
}

function Export-INRSettings {
    <#
    .SYNOPSIS
    Persists the GUI settings to Settings.json using an atomic write.
    .DESCRIPTION
    Serializes to a temp file and replaces the target with Move-Item so a
    partial write cannot corrupt Settings.json if the process is killed.
    .PARAMETER RootPath
    Repository root.
    .PARAMETER Settings
    The settings object to persist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,
        [Parameter(Mandatory)]
        [psobject]$Settings
    )

    $path = Get-INRSettingsPath -RootPath $RootPath
    $json = $Settings | ConvertTo-Json -Depth 8

    # Atomic write: serialize to temp, then replace target so partial writes
    # cannot corrupt Settings.json if PowerShell is killed mid-save.
    $tempPath = "$path.tmp"
    try {
        Set-Content -LiteralPath $tempPath -Value $json -Encoding UTF8
        Move-Item -LiteralPath $tempPath -Destination $path -Force
    } catch {
        if (Test-Path -LiteralPath $tempPath) {
            try { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue } catch { }
        }
        throw
    }
}

Export-ModuleMember -Function @(
    'Get-INRSettingsPath',
    'Get-INRDefaultSettings',
    'Import-INRSettings',
    'Export-INRSettings'
)
