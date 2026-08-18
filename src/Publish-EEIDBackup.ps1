<#
.SYNOPSIS
    Uploads an Export-EEID output folder to Azure Blob Storage and/or S3.
.DESCRIPTION
    Recursively uploads every file under -Path, preserving relative paths as
    blob/object keys, with Content-Type set to application/json.

    Encryption at rest is provided by the storage backend:
    - Azure Storage encrypts all data automatically (Microsoft-managed keys by
      default) -- nothing to configure here.
    - S3 does not guarantee this by default, so every object is uploaded with
      -ServerSideEncryption AES256 explicitly set, regardless of the target
      bucket's own default-encryption configuration.

    Uses whatever Azure/AWS credential context the caller already established
    (Connect-AzAccount / AWS credential chain), so it works the same whether that
    context came from an interactive login, a certificate, a managed identity, or
    workload identity federation in a CI/CD pipeline.
.PARAMETER Path
    Local directory to upload, typically the -Path passed to Export-EEID.
.PARAMETER AzureStorageAccount
    Name of the Azure Storage account to upload to. Requires the Az.Storage module
    and an active Connect-AzAccount context.
.PARAMETER Container
    Azure Blob Storage container name. Required with -AzureStorageAccount.
.PARAMETER S3Bucket
    Name of the S3 bucket to upload to. Requires the AWS.Tools.S3 module and valid
    AWS credentials in the environment/credential chain.
.PARAMETER S3Region
    AWS region for the S3 bucket. Defaults to the region configured in the active
    AWS credential/profile if omitted.
.PARAMETER Prefix
    Optional key/blob-name prefix applied to every uploaded object (e.g. a date
    stamp or environment name).
.EXAMPLE
    Publish-EEIDBackup -Path ./backup -AzureStorageAccount mystorageacct -Container eeid-backups -Prefix (Get-Date -Format 'yyyy-MM-dd')
.EXAMPLE
    Publish-EEIDBackup -Path ./backup -S3Bucket my-eeid-backups -S3Region eu-west-1
#>
function Publish-EEIDBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$AzureStorageAccount,

        [Parameter(Mandatory = $false)]
        [string]$Container,

        [Parameter(Mandatory = $false)]
        [string]$S3Bucket,

        [Parameter(Mandatory = $false)]
        [string]$S3Region,

        [Parameter(Mandatory = $false)]
        [string]$Prefix = ''
    )

    if (!$AzureStorageAccount -and !$S3Bucket) {
        throw "Specify at least one destination: -AzureStorageAccount (with -Container) or -S3Bucket."
    }

    if ($AzureStorageAccount -and !$Container) {
        throw "-Container is required when -AzureStorageAccount is specified."
    }

    $files = Get-ChildItem -Path $Path -Recurse -File

    if (!$files) {
        Write-Warning "No files found under '$Path', nothing to publish."
        return
    }

    function _relativeKey {
        param([string]$FullName, [string]$BasePath, [string]$KeyPrefix)

        $relative = $FullName.Substring($BasePath.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($KeyPrefix) {
            return "$($KeyPrefix.Trim('/'))/$relative"
        }
        return $relative
    }

    if ($AzureStorageAccount) {
        if (!(Get-Module -ListAvailable -Name Az.Storage)) {
            throw "The Az.Storage module is required to publish to Azure Blob Storage. Install it with: Install-Module Az.Storage"
        }
        Import-Module Az.Storage -ErrorAction Stop

        $ctx = New-AzStorageContext -StorageAccountName $AzureStorageAccount -UseConnectedAccount

        foreach ($file in $files) {
            $key = _relativeKey -FullName $file.FullName -BasePath $Path -KeyPrefix $Prefix
            Write-Verbose "Uploading '$($file.FullName)' to Azure container '$Container' as blob '$key'"
            Set-AzStorageBlobContent -Context $ctx -Container $Container -Blob $key -File $file.FullName -Properties @{ ContentType = 'application/json' } -Force | Out-Null
        }

        Write-Host "Published $($files.Count) file(s) to Azure Storage account '$AzureStorageAccount', container '$Container'."
    }

    if ($S3Bucket) {
        if (!(Get-Module -ListAvailable -Name AWS.Tools.S3)) {
            throw "The AWS.Tools.S3 module is required to publish to S3. Install it with: Install-Module AWS.Tools.S3"
        }
        Import-Module AWS.Tools.S3 -ErrorAction Stop

        $s3Params = @{ BucketName = $S3Bucket }
        if ($S3Region) { $s3Params.Region = $S3Region }

        foreach ($file in $files) {
            $key = _relativeKey -FullName $file.FullName -BasePath $Path -KeyPrefix $Prefix
            Write-Verbose "Uploading '$($file.FullName)' to S3 bucket '$S3Bucket' as key '$key'"
            Write-S3Object @s3Params -File $file.FullName -Key $key -ContentType 'application/json' -ServerSideEncryption AES256 | Out-Null
        }

        Write-Host "Published $($files.Count) file(s) to S3 bucket '$S3Bucket' (SSE-S3 AES256)."
    }
}
