BeforeAll {
    . "$PSScriptRoot/../src/Publish-EEIDBackup.ps1"

    # Stand-ins for the Az.Storage / AWS.Tools.S3 cmdlets so they can be mocked
    # without requiring either module to actually be installed in the test environment.
    function New-AzStorageContext { param($StorageAccountName, [switch]$UseConnectedAccount) }
    function Set-AzStorageBlobContent { param($Context, $Container, $Blob, $File, $Properties, [switch]$Force) }
    function Write-S3Object { param($BucketName, $Region, $File, $Key, $ContentType, $ServerSideEncryption) }

    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "eeid-publish-tests-$(Get-Random)"
    New-Item -Path (Join-Path $tempDir 'Organization') -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path $tempDir 'Organization/Organization.json') -Value '{"id":"x"}'
    Set-Content -Path (Join-Path $tempDir 'Domains.json') -Value '{"id":"y"}'
}

AfterAll {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Publish-EEIDBackup' {
    Context 'parameter validation' {
        It 'throws when neither destination is specified' {
            { Publish-EEIDBackup -Path $tempDir } | Should -Throw '*destination*'
        }

        It 'throws when -AzureStorageAccount is given without -Container' {
            { Publish-EEIDBackup -Path $tempDir -AzureStorageAccount 'acct' } | Should -Throw '*Container*'
        }

        It 'throws when -Path does not exist' {
            { Publish-EEIDBackup -Path (Join-Path $tempDir 'does-not-exist') -S3Bucket 'bucket' } | Should -Throw
        }
    }

    Context 'Azure upload' {
        BeforeAll {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'Az.Storage' }
            Mock Import-Module {}
            Mock New-AzStorageContext { 'fake-context' }
            Mock Set-AzStorageBlobContent {}
        }

        It 'uploads every file with a relative-path blob key' {
            Publish-EEIDBackup -Path $tempDir -AzureStorageAccount 'myacct' -Container 'eeid-backups'

            Should -Invoke Set-AzStorageBlobContent -Times 2 -Exactly
            Should -Invoke Set-AzStorageBlobContent -ParameterFilter { $Blob -eq 'Organization/Organization.json' }
            Should -Invoke Set-AzStorageBlobContent -ParameterFilter { $Blob -eq 'Domains.json' }
        }

        It 'applies the given prefix to every blob key' {
            Publish-EEIDBackup -Path $tempDir -AzureStorageAccount 'myacct' -Container 'eeid-backups' -Prefix '2026-08-18'

            Should -Invoke Set-AzStorageBlobContent -ParameterFilter { $Blob -eq '2026-08-18/Domains.json' }
        }

        It 'throws a clear error when Az.Storage is not installed' {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Az.Storage' }

            { Publish-EEIDBackup -Path $tempDir -AzureStorageAccount 'myacct' -Container 'eeid-backups' } | Should -Throw '*Install-Module Az.Storage*'
        }
    }

    Context 'S3 upload' {
        BeforeAll {
            Mock Get-Module { $true } -ParameterFilter { $Name -eq 'AWS.Tools.S3' }
            Mock Import-Module {}
            Mock Write-S3Object {}
        }

        It 'always uploads with AES256 server-side encryption' {
            Publish-EEIDBackup -Path $tempDir -S3Bucket 'my-bucket'

            Should -Invoke Write-S3Object -Times 2 -Exactly
            Should -Invoke Write-S3Object -ParameterFilter { $ServerSideEncryption -eq 'AES256' } -Times 2 -Exactly
        }

        It 'throws a clear error when AWS.Tools.S3 is not installed' {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'AWS.Tools.S3' }

            { Publish-EEIDBackup -Path $tempDir -S3Bucket 'my-bucket' } | Should -Throw '*Install-Module AWS.Tools.S3*'
        }
    }
}
