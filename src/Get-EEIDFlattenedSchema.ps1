<#
 .Synopsis
    Recursively flattens the ExportSchema structure to get all entries including nested ones.
#>

function Get-EEIDFlattenedSchema {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [object]$ExportSchema
    )

    foreach ($entry in $ExportSchema) {
        $entry

        if ($entry.'Children') {
            Get-EEIDFlattenedSchema -ExportSchema $entry.Children
        }
    }
}
