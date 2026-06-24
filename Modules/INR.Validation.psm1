Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'INR.ServiceCatalog.psm1') -Force

function Get-INRAvailableASAs {
    <#
    .SYNOPSIS
    Returns the ordered list of service areas selectable in the GUI.
    .DESCRIPTION
    Sourced from the shared catalog (Data/ServiceAreas.psd1) so the GUI list
    can never drift out of sync with the core script.
    #>
    [CmdletBinding()]
    param()

    return Get-INRGuiServiceAreaName
}

function Get-INRAdditionalASAs {
    <#
    .SYNOPSIS
    Returns the "additional" service areas that require a custom CSV and are
    excluded from -TestAllServiceAreas.
    #>
    [CmdletBinding()]
    param()

    return Get-INRAdditionalServiceAreaName
}

function Test-INRCustomCsvFormat {
    <#
    .SYNOPSIS
    Validates that a custom URL CSV maps to the expected URL,Port,Protocol,ID
    columns and contains usable values.
    .PARAMETER CsvPath
    Path to the CSV file to validate.
    .OUTPUTS
    A [pscustomobject] with IsValid (bool) and Message (string).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath
    )

    if (-not (Test-Path -LiteralPath $CsvPath)) {
        return [pscustomobject]@{ IsValid = $false; Message = 'CSV path does not exist.' }
    }

    if ([System.IO.Path]::GetExtension($CsvPath).ToLowerInvariant() -ne '.csv') {
        return [pscustomobject]@{ IsValid = $false; Message = 'Selected file must be a CSV file.' }
    }

    try {
        $rows = Import-Csv -LiteralPath $CsvPath -Header URL,Port,Protocol,ID
        if (-not $rows -or $rows.Count -lt 1) {
            return [pscustomobject]@{ IsValid = $false; Message = 'CSV is empty.' }
        }

        $first = $rows | Select-Object -First 1
        if (-not $first.URL -or -not $first.Port -or -not $first.Protocol -or -not $first.ID) {
            return [pscustomobject]@{ IsValid = $false; Message = 'CSV must map to URL, Port, Protocol, ID.' }
        }

        foreach ($row in $rows | Select-Object -First 30) {
            if (-not ($row.Port -as [int])) {
                return [pscustomobject]@{ IsValid = $false; Message = 'CSV contains non-numeric Port values.' }
            }
            if ($row.Protocol -notin @('TCP','UDP','tcp','udp')) {
                return [pscustomobject]@{ IsValid = $false; Message = 'Protocol must be TCP or UDP.' }
            }
        }
    } catch {
        return [pscustomobject]@{ IsValid = $false; Message = "CSV validation failed: $($_.Exception.Message)" }
    }

    return [pscustomobject]@{ IsValid = $true; Message = 'CSV format appears valid.' }
}

function Get-INROverlapWarnings {
    <#
    .SYNOPSIS
    Returns advisory warnings when the selected service areas overlap and may
    test the same endpoints redundantly.
    .PARAMETER SelectedASAs
    The service areas currently selected in the GUI.
    #>
    [CmdletBinding()]
    param(
        [string[]]$SelectedASAs
    )

    $warnings = [System.Collections.Generic.List[string]]::new()

    if ('Intune' -in $SelectedASAs -and 'Autopilot' -in $SelectedASAs) {
        $warnings.Add('Intune and Autopilot overlap heavily. Autopilot-related tests can run redundantly.')
    }
    if ('WindowsStore' -in $SelectedASAs -and 'AppInstaller' -in $SelectedASAs) {
        $warnings.Add('AppInstaller relies on Store requirements. Running both may duplicate testing.')
    }
    if ('WindowsStore' -in $SelectedASAs -and 'DeliveryOptimization' -in $SelectedASAs) {
        $warnings.Add('WindowsStore includes dependencies overlapping DeliveryOptimization.')
    }
    if ('WindowsStore' -in $SelectedASAs -and 'WindowsNotificationService' -in $SelectedASAs) {
        $warnings.Add('WindowsStore includes dependencies overlapping WindowsNotificationService.')
    }
    if ('Autopilot' -in $SelectedASAs -and 'TPMAttestation' -in $SelectedASAs) {
        $warnings.Add('Autopilot includes TPM attestation-related dependencies.')
    }

    return $warnings.ToArray()
}

function Test-INRAdditionalAsaRules {
    <#
    .SYNOPSIS
    Evaluates the rules that apply when an "additional" service area is
    selected: the MS/MS365 JSON sources must be disabled and a custom CSV is
    required.
    .PARAMETER SelectedASAs
    The service areas currently selected in the GUI.
    .PARAMETER UseMSJSON
    Whether the MS (MEM) JSON source is enabled.
    .PARAMETER UseMS365JSON
    Whether the MS365 JSON source is enabled.
    .PARAMETER UseCustomCsv
    Whether a custom CSV source is enabled.
    #>
    [CmdletBinding()]
    param(
        [string[]]$SelectedASAs,
        [bool]$UseMSJSON,
        [bool]$UseMS365JSON,
        [bool]$UseCustomCsv
    )

    $additional = Get-INRAdditionalASAs
    $hasAdditional = $SelectedASAs | Where-Object { $_ -in $additional } | Measure-Object | Select-Object -ExpandProperty Count
    if ($hasAdditional -gt 0) {
        return [pscustomobject]@{
            HasAdditionalASAs = $true
            MustDisableMSJson = $true
            MustRequireCustomCsv = -not $UseCustomCsv
            Message = 'Additional ASAs selected. UseMSJSON/UseMS365JSON must be disabled and a custom CSV is required.'
        }
    }

    return [pscustomobject]@{
        HasAdditionalASAs = $false
        MustDisableMSJson = $false
        MustRequireCustomCsv = $false
        Message = ''
    }
}

Export-ModuleMember -Function @(
    'Get-INRAvailableASAs',
    'Get-INRAdditionalASAs',
    'Test-INRCustomCsvFormat',
    'Get-INROverlapWarnings',
    'Test-INRAdditionalAsaRules'
)
