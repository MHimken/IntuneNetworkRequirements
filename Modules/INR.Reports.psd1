@{
    RootModule        = 'INR.Reports.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '955b0fdd-b642-4bb7-8e83-733cfebf1a66'
    Author            = 'INRdev'
    Description       = 'Generates HTML scan and run-comparison reports from result CSVs (with HTML-encoded values).'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'ConvertTo-INRHtmlText',
        'ConvertTo-INRStatusEmoji',
        'ConvertTo-INRJsonForHtml',
        'New-INRMindMapReport',
        'New-INRComparisonReport'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
