@{
    RootModule        = 'INR.Execution.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'ee037b58-993b-41a3-82c7-4363702898e2'
    Author            = 'INRdev'
    Description       = 'Builds arguments for and runs the core script as a child process, streaming progress to the GUI.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Test-INRScriptMarker',
        'Resolve-INRCustomCsvArgument',
        'New-INRArgumentList',
        'Start-INRRun',
        'Stop-INRRun',
        'Get-INRRunStatus',
        'Reset-INRRunState',
        'Get-INRNewOutput',
        'Get-INREta'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
