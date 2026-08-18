@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'EntraExternalIDExporter.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = 'Core'

    # ID used to uniquely identify this module
    GUID = 'a3f9e6c2-7b4d-4e1a-9c3e-1d2f5a6b8c9d'

    # Author of this module
    Author = 'Agnivesh S'

    # Description of the functionality provided by this module
    Description = 'Exports a Microsoft Entra External ID external (CIAM) tenant''s configuration -- user flows, identity providers, branding, policies, Conditional Access, applications, and users -- to JSON files for backup and version control.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.8.0' }
    )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @('EntraExternalIDExporterEnums.ps1')

    # Functions to export from this module.
    FunctionsToExport = @(
        'Connect-EEIDExporter'
        'Export-EEID'
        'Publish-EEIDBackup'
        'Get-EEIDRequiredScopes'
    )

    # Cmdlets to export from this module.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module.
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags = 'Microsoft', 'Entra', 'ExternalID', 'CIAM', 'Identity', 'Export', 'Backup', 'DR'
            LicenseUri = 'https://raw.githubusercontent.com/agnivesh/EEID-Exporter/main/LICENSE'
            ProjectUri = 'https://github.com/agnivesh/EEID-Exporter'
        }
    }
}
