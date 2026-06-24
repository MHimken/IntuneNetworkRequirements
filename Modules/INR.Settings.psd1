@{
    RootModule        = 'INR.Settings.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '6b28c8d5-424c-45d8-a5fc-1eabc0a423b6'
    Author            = 'INRdev'
    Description       = 'Loads, defaults, and atomically persists the INRWithGUI Settings.json.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-INRSettingsPath',
        'Get-INRDefaultSettings',
        'Import-INRSettings',
        'Export-INRSettings'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
