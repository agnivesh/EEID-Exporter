BeforeAll {
    . "$PSScriptRoot/../src/EntraExternalIDExporterEnums.ps1"
    . "$PSScriptRoot/../src/internal/ConvertFrom-QueryString.ps1"
    . "$PSScriptRoot/../src/internal/ConvertTo-QueryString.ps1"
    . "$PSScriptRoot/../src/internal/Get-ObjectProperty.ps1"
    . "$PSScriptRoot/../src/internal/New-FinalUri.ps1"
    . "$PSScriptRoot/../src/internal/New-GraphBatchRequest.ps1"
    . "$PSScriptRoot/../src/internal/Invoke-GraphBatchRequest.ps1"
    . "$PSScriptRoot/../src/Get-EEIDDefaultSchema.ps1"
    . "$PSScriptRoot/../src/Get-EEIDFlattenedSchema.ps1"
    . "$PSScriptRoot/../src/Export-EEID.ps1"

    function Write-BatchError {
        param([int]$Status, [string]$Message)
        $exception = [System.InvalidOperationException]::new($Message)
        $exception.Source = 'BatchRequest'
        $target = [ordered]@{ request = @{ id = 'Test' }; response = @{ status = $Status } }
        Write-Error -ErrorRecord ([System.Management.Automation.ErrorRecord]::new($exception, $null, 'InvalidOperation', $target))
    }

    $script:schema = @(
        @{
            Path = 'Test'; GraphUri = 'domains'; Tag = @('All', 'Config')
            DelegatedPermission = 'Domain.Read.All'; IgnoreError = 'feature is not enabled'
        }
    )

    Mock Get-MgContext { [pscustomobject]@{ AuthType = 'Delegated' } }
}

Describe 'Export-EEID batch error handling' {
    It 'reports a 400 response instead of ignoring it' {
        Mock Invoke-GraphBatchRequest { Write-BatchError -Status 400 -Message 'Invalid filter clause' }

        { Export-EEID -Path $TestDrive -ExportSchema $schema -ErrorAction Stop 6>$null } |
            Should -Throw '*Invalid filter clause*'
    }

    It 'ignores a 404 response' {
        Mock Invoke-GraphBatchRequest { Write-BatchError -Status 404 -Message 'Not found' }

        { Export-EEID -Path $TestDrive -ExportSchema $schema -ErrorAction Stop 6>$null } | Should -Not -Throw
    }

    It 'ignores errors matching the schema IgnoreError text' {
        Mock Invoke-GraphBatchRequest { Write-BatchError -Status 400 -Message 'The feature is not enabled for the tenant' }

        { Export-EEID -Path $TestDrive -ExportSchema $schema -ErrorAction Stop 6>$null } | Should -Not -Throw
    }
}

Describe 'Export-EEID -CloudUsersAndGroupsOnly' {
    BeforeAll {
        $script:userSchema = @(
            @{
                Path = 'Users'; GraphUri = 'users'; Tag = @('All', 'Users'); Filter = 'accountEnabled eq true'
                DelegatedPermission = 'User.Read.All'
            }
        )
    }

    It 'adds the sync filter to the users request without modifying the schema' {
        $script:url = $null
        Mock Invoke-GraphBatchRequest {
            $script:url = [uri]::UnescapeDataString($batchRequest[0].Url) -replace '\+', ' '
            [pscustomobject]@{ id = 'u1'; RequestId = $batchRequest[0].Id }
        }

        Export-EEID -Path $TestDrive -Type Users -ExportSchema $userSchema -CloudUsersAndGroupsOnly 6>$null

        $url | Should -BeLike '*accountEnabled eq true and (onPremisesSyncEnabled ne true)*'
        $userSchema[0].Filter | Should -Be 'accountEnabled eq true'
    }
}

Describe 'Export-EEID output safety' {
    It 'does not write results whose id contains a path separator' {
        Mock Invoke-GraphBatchRequest { [pscustomobject]@{ id = '../evil'; RequestId = $batchRequest[0].Id } }
        $outDir = Join-Path $TestDrive 'out'

        Export-EEID -Path $outDir -ExportSchema $schema -ErrorAction SilentlyContinue 6>$null

        Get-ChildItem -Path $TestDrive -Recurse -Filter '*.json' | Should -BeNullOrEmpty
    }
}
