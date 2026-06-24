@{
    RootModule        = 'INR.Context.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '2beeb3e1-afbd-4a4f-998f-a7038be8fdaf'
    Author            = 'INRdev'
    Description       = 'Maintains the INRWithGUI development context files (context.json and context.md).'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-INRContextPath',
        'Get-INRContextMarkdownPath',
        'Initialize-INRContext',
        'Update-INRContextStatus'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
