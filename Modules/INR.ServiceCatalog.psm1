Set-StrictMode -Version Latest

#
# INR.ServiceCatalog.psm1 - loads and exposes the service-area (ASA) catalog
# defined in Data/ServiceAreas.psd1 so that both the GUI modules and the core
# script share a single source of truth.
#

$script:ServiceAreaCache = $null

function Get-INRServiceCatalogPath {
    <#
    .SYNOPSIS
    Returns the absolute path to the service-area catalog data file.
    .PARAMETER RootPath
    Repository root. Defaults to the parent of this module's Modules folder.
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath
    )

    if (-not $RootPath) {
        $RootPath = Split-Path -Path $PSScriptRoot -Parent
    }
    return Join-Path -Path $RootPath -ChildPath 'Data/ServiceAreas.psd1'
}

function Get-INRServiceCatalog {
    <#
    .SYNOPSIS
    Loads the service-area catalog as an ordered array of hashtables.
    .DESCRIPTION
    Reads Data/ServiceAreas.psd1 once and caches the result. Throws a clear
    error if the file is missing or malformed so callers fail loudly rather
    than silently testing nothing.
    .PARAMETER RootPath
    Repository root passed through to Get-INRServiceCatalogPath.
    .PARAMETER Force
    Reload from disk even if a cached copy exists.
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath,
        [switch]$Force
    )

    if ($script:ServiceAreaCache -and -not $Force) {
        return $script:ServiceAreaCache
    }

    $path = Get-INRServiceCatalogPath -RootPath $RootPath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Service-area catalog not found at '$path'. The INR catalog (Data/ServiceAreas.psd1) is required."
    }

    try {
        $data = Import-PowerShellDataFile -LiteralPath $path
    } catch {
        throw "Service-area catalog at '$path' could not be parsed: $($_.Exception.Message)"
    }

    if (-not $data.ContainsKey('ServiceAreas') -or -not $data.ServiceAreas) {
        throw "Service-area catalog at '$path' does not define a non-empty 'ServiceAreas' collection."
    }

    $script:ServiceAreaCache = @($data.ServiceAreas)
    return $script:ServiceAreaCache
}

function Get-INRServiceArea {
    <#
    .SYNOPSIS
    Returns the catalog entry for a single service area by name.
    .PARAMETER Name
    Canonical service-area name (matches the script switch and GUI label).
    .PARAMETER RootPath
    Repository root passed through to Get-INRServiceCatalog.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$RootPath
    )

    return Get-INRServiceCatalog -RootPath $RootPath | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
}

function Get-INRGuiServiceAreaName {
    <#
    .SYNOPSIS
    Returns the ordered list of service-area names shown in the GUI.
    .PARAMETER RootPath
    Repository root passed through to Get-INRServiceCatalog.
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath
    )

    return @(Get-INRServiceCatalog -RootPath $RootPath | Where-Object { $_.ShowInGui } | ForEach-Object { $_.Name })
}

function Get-INRAdditionalServiceAreaName {
    <#
    .SYNOPSIS
    Returns the names of the "additional" service areas (excluded from
    -TestAllServiceAreas, require a custom CSV in the GUI).
    .PARAMETER RootPath
    Repository root passed through to Get-INRServiceCatalog.
    #>
    [CmdletBinding()]
    param(
        [string]$RootPath
    )

    return @(Get-INRServiceCatalog -RootPath $RootPath | Where-Object { $_.Additional } | ForEach-Object { $_.Name })
}

Export-ModuleMember -Function @(
    'Get-INRServiceCatalogPath',
    'Get-INRServiceCatalog',
    'Get-INRServiceArea',
    'Get-INRGuiServiceAreaName',
    'Get-INRAdditionalServiceAreaName'
)
