BeforeAll {
    . "$PSScriptRoot/../src/EntraExternalIDExporterEnums.ps1"
    . "$PSScriptRoot/../src/internal/Get-ObjectProperty.ps1"
    . "$PSScriptRoot/../src/Get-EEIDDefaultSchema.ps1"
    . "$PSScriptRoot/../src/Get-EEIDFlattenedSchema.ps1"

    Mock Get-MgContext { return [pscustomobject]@{ TenantId = '00000000-0000-0000-0000-000000000000' } }

    $script:schema = Get-EEIDFlattenedSchema -ExportSchema (Get-EEIDDefaultSchema)
}

Describe 'Get-EEIDDefaultSchema' {
    It 'returns at least one entry' {
        $schema.Count | Should -BeGreaterThan 0
    }

    It 'every entry has either GraphUri or Command, but not both' {
        foreach ($entry in $schema) {
            $hasGraphUri = [bool]$entry.GraphUri
            $hasCommand = [bool]$entry.Command
            ($hasGraphUri -xor $hasCommand) | Should -BeTrue -Because "entry '$($entry.Path)' must define exactly one of GraphUri/Command"
        }
    }

    It 'every entry has a non-empty Path' {
        foreach ($entry in $schema) {
            $entry.Path | Should -Not -BeNullOrEmpty
        }
    }

    It 'every entry has a non-empty Tag' {
        foreach ($entry in $schema) {
            $entry.Tag | Should -Not -BeNullOrEmpty
        }
    }

    It 'every entry declares at least one delegated or application permission' {
        foreach ($entry in $schema) {
            ($entry.DelegatedPermission -or $entry.ApplicationPermission) | Should -BeTrue -Because "entry '$($entry.Path)' has no declared permission"
        }
    }

    It 'every Tag value is a valid ObjectType' {
        $validTags = [enum]::GetNames([ObjectType])
        foreach ($entry in $schema) {
            foreach ($tag in $entry.Tag) {
                $validTags | Should -Contain $tag
            }
        }
    }

    It 'tags user flows as part of the default Config export' {
        $userFlowEntry = (Get-EEIDDefaultSchema) | Where-Object { $_.GraphUri -eq 'identity/authenticationEventsFlows' }
        $userFlowEntry.Tag | Should -Contain 'Config'
        $userFlowEntry.Tag | Should -Contain 'UserFlows'
    }

    It 'does not export workforce-only workloads (Devices, Teams, PIM, AppProxy)' {
        $forbiddenUris = $schema.GraphUri | Where-Object {
            $_ -match '(?i)devicemanagement|onpremisespublishingprofiles|teamwork|sharepoint|privileged|entitlementmanagement'
        }
        $forbiddenUris | Should -BeNullOrEmpty
    }
}
