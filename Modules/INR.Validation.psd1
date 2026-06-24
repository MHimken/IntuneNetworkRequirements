@{
    RootModule        = 'INR.Validation.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'f20f8644-ddb5-43f7-b5af-40586e1d1373'
    Author            = 'INRdev'
    Description       = 'GUI input validation, ASA catalog access, and overlap warnings.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-INRAvailableASAs',
        'Get-INRAdditionalASAs',
        'Test-INRCustomCsvFormat',
        'Get-INROverlapWarnings',
        'Test-INRAdditionalAsaRules'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
