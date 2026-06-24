Set-StrictMode -Version Latest

function Get-INRContextPath {
    <#
    .SYNOPSIS
    Returns the absolute path to the machine-readable context file (context.json).
    .PARAMETER RootPath
    Repository root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    return Join-Path -Path $RootPath -ChildPath 'context.json'
}

function Get-INRContextMarkdownPath {
    <#
    .SYNOPSIS
    Returns the absolute path to the human-readable context log (context.md).
    .PARAMETER RootPath
    Repository root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    return Join-Path -Path $RootPath -ChildPath 'context.md'
}

function Initialize-INRContext {
    <#
    .SYNOPSIS
    Creates the context.json and context.md files with seed content if they do
    not already exist.
    .PARAMETER RootPath
    Repository root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    $jsonPath = Get-INRContextPath -RootPath $RootPath
    $mdPath = Get-INRContextMarkdownPath -RootPath $RootPath

    if (-not (Test-Path -LiteralPath $jsonPath)) {
        $context = [ordered]@{
            Project = 'INRWithGUI'
            LastUpdatedUtc = (Get-Date).ToUniversalTime().ToString('o')
            ImplementationStatus = 'initialized'
            Decisions = [ordered]@{
                GUIStack = 'WPF'
                Visualization = 'HTML+Mermaid'
                RunLocation = 'C:\\Temp\\INRWithGUI'
                ContextFormats = @('JSON', 'Markdown')
                RainbowProgressBar = $true
            }
            CompletedPhases = @('Phase1-Scaffold')
            OpenItems = @(
                'Complete full WPF interactions and validations',
                'Polish execution cancellation and status streaming',
                'Finalize advanced reporting and docs'
            )
        }
        $context | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    }

    if (-not (Test-Path -LiteralPath $mdPath)) {
        @(
            '# INRWithGUI Context Log',
            '',
            '## 2026-05-30',
            '- Initialized project scaffold in C:\\Temp\\INRWithGUI',
            '- Added modular architecture and WPF launcher entrypoint',
            '- Added rainbow progress bar requirement to implementation scope'
        ) | Set-Content -LiteralPath $mdPath -Encoding UTF8
    }
}

function Update-INRContextStatus {
    <#
    .SYNOPSIS
    Updates the implementation status in context.json and optionally appends a
    line to the context.md log.
    .PARAMETER RootPath
    Repository root.
    .PARAMETER Status
    The new implementation status to record.
    .PARAMETER AddCompletedPhase
    Phase names to add to the completed list (deduplicated).
    .PARAMETER AddOpenItem
    Open items to add (deduplicated).
    .PARAMETER AppendMarkdownLine
    A line to append to context.md as a bullet.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,
        [Parameter(Mandatory)]
        [string]$Status,
        [string[]]$AddCompletedPhase,
        [string[]]$AddOpenItem,
        [string]$AppendMarkdownLine
    )

    $jsonPath = Get-INRContextPath -RootPath $RootPath
    $mdPath = Get-INRContextMarkdownPath -RootPath $RootPath

    if (-not (Test-Path -LiteralPath $jsonPath)) {
        Initialize-INRContext -RootPath $RootPath
    }

    $context = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    $context.LastUpdatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $context.ImplementationStatus = $Status

    if ($AddCompletedPhase) {
        foreach ($phase in $AddCompletedPhase) {
            if ($phase -notin $context.CompletedPhases) {
                $context.CompletedPhases += $phase
            }
        }
    }

    if ($AddOpenItem) {
        foreach ($item in $AddOpenItem) {
            if ($item -notin $context.OpenItems) {
                $context.OpenItems += $item
            }
        }
    }

    $context | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    if ($AppendMarkdownLine) {
        if (-not (Test-Path -LiteralPath $mdPath)) {
            Initialize-INRContext -RootPath $RootPath
        }
        Add-Content -LiteralPath $mdPath -Value ("- " + $AppendMarkdownLine)
    }
}

Export-ModuleMember -Function @(
    'Get-INRContextPath',
    'Get-INRContextMarkdownPath',
    'Initialize-INRContext',
    'Update-INRContextStatus'
)
