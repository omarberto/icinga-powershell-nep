@{
    ModuleVersion     = '1.0.0'
    RootModule        = 'icinga-powershell-nep.psm1'
    GUID              = '78ecc87d-c49c-4207-8b52-5ebe7883b0d8'
    Author            = 'axadmin'
    CompanyName       = ''
    Copyright         = '(c) 2023 axadmin | GPL v2.0'
    Description       = ''
    PowerShellVersion = '4.0'
    RequiredModules   = @(
        @{ ModuleName = 'icinga-powershell-framework'; ModuleVersion = '1.7.0'; }
    )
    NestedModules     = @(
    )
    FunctionsToExport = @( '*' )
    CmdletsToExport   = @( '*' )
    VariablesToExport = @( '*' )
    AliasesToExport   = @( '*' )
    PrivateData       = @{
        PSData   = @{
            Tags         = @( 'nep' )
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = ''
        };
        Version  = 'v1.0.0'
        Name     = 'Windows nep';
        Type     = 'plugins';
        Function = '';
        Endpoint = '';
    }
    HelpInfoURI       = ''
}

