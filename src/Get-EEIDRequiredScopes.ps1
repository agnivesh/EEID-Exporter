<#
 .Synopsis
  Gets the required Graph scopes for the (filtered) export schema

 .Description
  Gets the required Graph scopes for the (filtered) export schema

 .Example
  Get-EEIDRequiredScopes -PermissionType Delegated
#>

function Get-EEIDRequiredScopes {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Delegated','Application')]
        [string]$PermissionType,

        [Parameter(Mandatory = $false)]
        [ObjectType[]]$Type,

        [Parameter(Mandatory = $false)]
        [object]$ExportSchema
    )

    if (!$ExportSchema) {
        $ExportSchema = Get-EEIDDefaultSchema
    }

    $scopeProperty = "DelegatedPermission"
    if ($PermissionType -eq "Application") {
        $scopeProperty = "ApplicationPermission"
    }

    $RequestedExportSchema = Get-EEIDFlattenedSchema -ExportSchema $ExportSchema

    if ($Type) {
        Write-Verbose "Filtering ExportSchema to only requested types: $($Type -join ', ')"
        # filter schema to only the requested types
        $RequestedExportSchema = $ExportSchema | ? { Compare-Object $_.Tag $Type -ExcludeDifferent -IncludeEqual }
    }

    $scopes = [System.Collections.Generic.List[Object]]::new()

    foreach ($entry in $RequestedExportSchema) {
        $entryScopes = $entry.$scopeProperty
        $graphUri = $entry.GraphUri

        if ($Type -and ($entry.Tag -notin $Type) -and ($entry.Tag -ne 'All')) {
            Write-Verbose "Skipping entry with tag '$($entry.Tag)' because it is not in the requested types"
            continue
        }

        if (!$entryScopes) {
            Write-Verbose "Call to graphuri '$graphUri' doesn't provide $PermissionType permissions"
        }

        foreach ($entryScope in $entryScopes) {
            if ($entryScope -notin $scopes) {
                $scopes.Add($entryScope)
            }
        }
    }

    $scopes | sort-object
}
