<#
.SYNOPSIS
    Authenticate against Microsoft Graph using delegated permissions (as user).
.DESCRIPTION
    Authenticate against Microsoft Graph using delegated permissions (as user), for
    an External ID external (CIAM) tenant.

    To authenticate using a certificate, client secret, managed identity, or workload
    identity federation (for unattended CI/CD runs), call Connect-MgGraph directly
    instead -- see the README for examples.
.EXAMPLE
    PS C:\>Connect-EEIDExporter -TenantId 3043-343434-343434
    Connect to the given external tenant, requesting the delegated scopes needed for
    the default 'Config' export type.
.EXAMPLE
    PS C:\>Connect-EEIDExporter -TenantId 3043-343434-343434 -Type Users, Applications
    Connect to a specific tenant. Correct delegated Graph scopes will be automatically
    requested based on the types specified.
#>
function Connect-EEIDExporter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [ArgumentCompleter( {
            param ( $CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters )
            (Get-MgEnvironment).Name
        } )]
        [string]$Environment = 'Global',

        [Parameter(ParameterSetName = 'SelectTypes', Mandatory = $false)]
        [ObjectType[]]$Type = 'Config',

        # Perform a full export of all available configuration item types.
        [Parameter(ParameterSetName = 'AllTypes', Mandatory = $true)]
        [switch]$All,

        # Specifies the schema to use for the export. If not specified, the default schema will be used.
        [object]$ExportSchema
    )

    if ($All) { $Type = @('All') }

    if (!$ExportSchema) {
        $ExportSchema = Get-EEIDDefaultSchema
    }

    $graphScope = Get-EEIDRequiredScopes -PermissionType 'Delegated' -Type $Type -ExportSchema $ExportSchema

    Write-Verbose "Connecting to Graph with scopes: $($graphScope -join ', ')"
    Connect-MgGraph -TenantId $TenantId -Environment $Environment -Scopes $graphScope
}
