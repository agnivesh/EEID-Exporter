<#
.DISCLAIMER
    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
    ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
    THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
    PARTICULAR PURPOSE.
#>

## Dot-source every internal helper and public cmdlet, then export only the public surface.

$internal = Get-ChildItem -Path (Join-Path $PSScriptRoot 'internal') -Filter '*.ps1'
$public = Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' | Where-Object { $_.Name -ne 'EntraExternalIDExporterEnums.ps1' }

foreach ($file in @($internal) + @($public)) {
    . $file.FullName
}

Export-ModuleMember -Function 'Connect-EEIDExporter', 'Export-EEID', 'Publish-EEIDBackup', 'Get-EEIDRequiredScopes'
