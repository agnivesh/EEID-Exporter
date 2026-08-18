BeforeAll {
    . "$PSScriptRoot/../src/EntraExternalIDExporterEnums.ps1"
    . "$PSScriptRoot/../src/internal/Get-ObjectProperty.ps1"
    . "$PSScriptRoot/../src/Get-EEIDDefaultSchema.ps1"
    . "$PSScriptRoot/../src/Get-EEIDFlattenedSchema.ps1"
    . "$PSScriptRoot/../src/Get-EEIDRequiredScopes.ps1"

    Mock Get-MgContext { return [pscustomobject]@{ TenantId = '00000000-0000-0000-0000-000000000000' } }
}

Describe 'Get-EEIDRequiredScopes' {
    It 'returns a sorted, de-duplicated list of delegated scopes for the default Config type' {
        $scopes = Get-EEIDRequiredScopes -PermissionType Delegated -Type Config

        $scopes.Count | Should -BeGreaterThan 0
        ($scopes | Sort-Object) | Should -Be $scopes
        ($scopes | Select-Object -Unique).Count | Should -Be $scopes.Count
    }

    It 'includes IdentityUserFlow.Read.All when UserFlows type is requested' {
        $scopes = Get-EEIDRequiredScopes -PermissionType Delegated -Type UserFlows

        $scopes | Should -Contain 'IdentityUserFlow.Read.All'
    }

    It 'includes User.Read.All only when Users type is requested' {
        $configScopes = Get-EEIDRequiredScopes -PermissionType Delegated -Type Config
        $userScopes = Get-EEIDRequiredScopes -PermissionType Delegated -Type Users

        $configScopes | Should -Not -Contain 'User.Read.All'
        $userScopes | Should -Contain 'User.Read.All'
    }

    It 'returns application scopes when PermissionType is Application' {
        $scopes = Get-EEIDRequiredScopes -PermissionType Application -Type Config

        $scopes.Count | Should -BeGreaterThan 0
    }
}
