@{
    RootModule        = 'INR.ServiceCatalog.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '62b5ce67-fbb3-417b-9b78-57c474831823'
    Author            = 'INRdev'
    Description       = 'Loads the shared service-area (ASA) catalog from Data/ServiceAreas.psd1.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-INRServiceCatalogPath',
        'Get-INRServiceCatalog',
        'Get-INRServiceArea',
        'Get-INRGuiServiceAreaName',
        'Get-INRAdditionalServiceAreaName'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
