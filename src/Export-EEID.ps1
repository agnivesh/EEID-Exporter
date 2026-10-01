function Export-EEID {
    <#
    .SYNOPSIS
    Exports a Microsoft Entra External ID external (CIAM) tenant's configuration and settings.

    .DESCRIPTION
    This cmdlet reads configuration from the target External ID tenant via the
    Microsoft Graph API and writes the result to JSON files in a target directory,
    one file per object, mirroring the Graph resource hierarchy.

    .PARAMETER Path
    Specifies the directory path where the output files will be generated.

    .PARAMETER Type
    Specifies the type of objects to export.
    Defaults to 'Config', which exports the tenant's key CIAM configuration: user
    flows, identity providers, branding, policies, and Conditional Access.

    The available types are:
        'All','Applications','Config','ConditionalAccess','Groups','Roles','ServicePrincipals','UserFlows','Users'

    To see what each type exports, check src\Get-EEIDDefaultSchema.ps1

    .PARAMETER All
    If specified performs a full export of all objects and configuration in the tenant,
    including Applications, ServicePrincipals, Groups, and Users.

    .PARAMETER CloudUsersAndGroupsOnly
    Excludes synced on-premises users and groups from the export (relevant only if the
    tenant has hybrid sync configured). Only cloud-managed users and groups will be included.

    .EXAMPLE
    Export-EEID -Path 'C:\EEIDBackup\'

    Runs a default export: user flows, identity providers, branding, policies, and
    Conditional Access. Does not include large data collections such as users, groups,
    applications, or service principals.

    .EXAMPLE
    Export-EEID -Path 'C:\EEIDBackup\' -All

    Runs a full export of all objects and configuration settings.

    .EXAMPLE
    Export-EEID -Path 'C:\EEIDBackup\' -Type UserFlows, Applications

    Runs an export that includes just the user flows and application registrations.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SelectTypes')]
    param (
        # The directory path where the output files will be generated.
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'AllTypes')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SelectTypes')]
        [String]$Path,

        [Parameter(ParameterSetName = 'SelectTypes')]
        [ObjectType[]]$Type = 'Config',

        # Perform a full export of all available configuration item types.
        [Parameter(ParameterSetName = 'AllTypes')]
        [switch]$All,

        # Exclude synced on-premises users and groups from the export. Only cloud-managed users and groups will be included.
        [Parameter(Mandatory = $false, ParameterSetName = 'AllTypes')]
        [Parameter(Mandatory = $false, ParameterSetName = 'SelectTypes')]
        [switch]$CloudUsersAndGroupsOnly,

        # Specifies the schema to use for the export. If not specified, the default schema will be used.
        [Parameter(Mandatory = $false, ParameterSetName = 'AllTypes')]
        [Parameter(Mandatory = $false, ParameterSetName = 'SelectTypes')]
        [object]$ExportSchema
    )

    $mgContext = Get-MgContext

    if (!$mgContext) {
        throw 'No active connection. Run Connect-EEIDExporter or Connect-MgGraph to sign in and then retry.'
    }

    if ($All) { $Type = @('All') }

    if (!$ExportSchema) {
        $ExportSchema = Get-EEIDDefaultSchema
    }

    $authScope = $mgContext.AuthType
    if ($authScope -eq "Delegated") {
        $schemaScopeType = "DelegatedPermission"
    } else {
        $schemaScopeType = "ApplicationPermission"
    }

    #region helper functions
    function _randomizeRequestId {
        <#
        Adds a random number to the request ID to avoid duplicates in batch requests.

        Request ID in batch requests must be unique. I am using 'Path' property from $ExportSchema as the request ID.
        However, there can be multiple $ExportSchema items with the same path which would lead to duplicated request IDs in the batch request and failure of the whole batch.
        To avoid this, I am appending a random number to the request ID.
        #>

        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$requestId
        )

        # add a random number to avoid duplicated ids in batch requests
        $requestId + "%%%" + (Get-Random) + "%%%"
    }

    function _normalizeRequestId {
        <#
        Removes the randomization string (added to the request ID to avoid duplicates in batch requests).
        #>

        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string]$requestId
        )

        # remove the random string added to avoid duplicated ids in batch requests
        $requestId -replace "\%\%\%\d+\%\%\%", ""
    }

    function _getEntryUri {
        <#
        Builds the relative request URI for a schema entry, adding the cloud-only filter
        to users and groups requests when requested. The schema itself is never modified.
        #>

        param(
            [Parameter(Mandatory = $true)]
            [object]$schemaEntry
        )

        $filter = Get-ObjectProperty $schemaEntry 'Filter'

        if ($CloudUsersAndGroupsOnly -and ((Get-ObjectProperty $schemaEntry 'GraphUri') -in 'users', 'groups')) {
            $syncFilter = 'onPremisesSyncEnabled ne true'
            $filter = if ([string]::IsNullOrEmpty($filter)) { $syncFilter } else { "$filter and ($syncFilter)" }
        }

        New-FinalUri -RelativeUri (Get-ObjectProperty $schemaEntry 'GraphUri') -Select (Get-ObjectProperty $schemaEntry 'Select') -QueryParameters (Get-ObjectProperty $schemaEntry 'QueryParameters') -Filter $filter
    }

    function _getEntryApiVersion {
        param(
            [Parameter(Mandatory = $true)]
            [object]$schemaEntry
        )

        $apiVersion = Get-ObjectProperty $schemaEntry 'ApiVersion'
        if ($apiVersion) { $apiVersion } else { 'v1.0' }
    }

    function _queueRequest {
        param(
            [Parameter(Mandatory = $true)]
            [object]$request,

            [Parameter(Mandatory = $true)]
            [string]$apiVersion
        )

        if ($apiVersion -eq 'beta') {
            $batchRequestBetaApi.Add($request)
        } else {
            $batchRequestStableApi.Add($request)
        }
    }

    function _processBatchErrors {
        param(
            [array]$requestErrors,
            [array]$requestedExportSchema
        )

        $ignorePatterns = @(Get-EEIDFlattenedSchema -ExportSchema $requestedExportSchema |
                ForEach-Object { $_.IgnoreError } | Select-Object -Unique)

        foreach ($err in $requestErrors) {
            if ($err.Exception.Source -ne "BatchRequest") {
                Write-Error $err
                continue
            }

            # the object may be deleted between listing and retrieving its details
            if ($err.TargetObject.response.status -eq 404) {
                Write-Verbose "Ignoring request with id '$($err.TargetObject.request.id)' as it returned status code 404"
                continue
            }

            $matchedPattern = $ignorePatterns | Where-Object { $err.Exception.Message -like "*$_*" } | Select-Object -First 1
            if ($matchedPattern) {
                Write-Verbose "Ignoring request with id '$($err.TargetObject.request.id)' as it returned error to ignore '$matchedPattern'"
                continue
            }

            Write-Error $err
        }
    }

    function _processChildrenRecursive {
        param(
            [array]$schemaItems,
            [string]$basePath,
            [array]$parentIds
        )

        foreach ($item in $schemaItems) {
            Write-Host " -> $($item.GraphUri)"

            if (!$item.$schemaScopeType) {
                Write-Verbose " - Skipping as it doesn't support '$schemaScopeType'"
                continue
            }

            $children = Get-ObjectProperty $item 'Children'
            $apiVersion = _getEntryApiVersion $item
            $uri = _getEntryUri $item

            $parentIds | % {
                if ($item.Path -match "\.json$") {
                    $outputFileName = Join-Path -Path $basePath -ChildPath $item.Path
                } else {
                    $outputFileName = Join-Path -Path $basePath -ChildPath $_
                    $outputFileName = Join-Path -Path $outputFileName -ChildPath $item.Path
                }
                # batch request id cannot contain '\' character
                $id = $outputFileName -replace '\\', '/'

                # to avoid duplicated ids in batch request if there are multiple $ExportSchema items with the same path
                $id = _randomizeRequestId $id

                Write-Verbose "Adding request '$uri' with id '$id' to the batch"

                $request = New-GraphBatchRequest -Url $uri -Id $id -placeholder $_ -header @{ ConsistencyLevel = 'eventual' }

                _queueRequest -request $request -apiVersion $apiVersion
            }

            # recursively process children if they exist
            if ($children) {
                $childBasePath = if ($item.Path -match "\.json$") {
                    $basePath
                } else {
                    Join-Path -Path $basePath -ChildPath $item.Path
                }

                # we'll process these after the current batch is executed and results are available
                $script:childrenToProcess.Add(@{
                    Children = $children
                    BasePath = $childBasePath
                    ParentPath = "$($item.Path)*"
                })
            }
        }
    }

    function _executeBatchRequests {
        param(
            [ref]$batchRequestStableApi,
            [ref]$batchRequestBetaApi,
            [ref]$results,
            [array]$requestedExportSchema
        )

        # execute v1.0 API batch requests
        if ($batchRequestStableApi.Value.Count -gt 0) {
            Write-Verbose "Processing $($batchRequestStableApi.Value.count) v1.0 API requests"
            $batchResults = Invoke-GraphBatchRequest -batchRequest $batchRequestStableApi.Value -separateErrors -ErrorAction SilentlyContinue -ErrorVariable requestErrors -WarningAction SilentlyContinue

            if ($batchResults) {
                $results.Value.AddRange(@($batchResults))
            }

            _processBatchErrors -requestErrors $requestErrors -requestedExportSchema $requestedExportSchema
            $batchRequestStableApi.Value.Clear()
        }

        # execute beta API batch requests
        if ($batchRequestBetaApi.Value.Count -gt 0) {
            Write-Verbose "Processing $($batchRequestBetaApi.Value.count) beta API requests"
            $batchResults = Invoke-GraphBatchRequest -batchRequest $batchRequestBetaApi.Value -graphVersion beta -separateErrors -ErrorAction SilentlyContinue -ErrorVariable requestErrors -WarningAction SilentlyContinue

            if ($batchResults) {
                $results.Value.AddRange(@($batchResults))
            }

            _processBatchErrors -requestErrors $requestErrors -requestedExportSchema $requestedExportSchema
            $batchRequestBetaApi.Value.Clear()
        }
    }
    #endregion helper functions

    #region process all schema items recursively
    $results = [System.Collections.Generic.List[Object]]::new()
    $batchRequestStableApi = [System.Collections.Generic.List[Object]]::new()
    $batchRequestBetaApi = [System.Collections.Generic.List[Object]]::new()
    $script:childrenToProcess = [System.Collections.Generic.List[Object]]::new()

    $requestedExportSchema = $ExportSchema | ? { Compare-Object $_.Tag $Type -ExcludeDifferent -IncludeEqual }

    # process root level items
    foreach ($item in $requestedExportSchema) {
        $outputFileName = Join-Path -Path $Path -ChildPath $item.Path

        Write-Host "==> $($item.GraphUri)"

        if (!$item.$schemaScopeType) {
            Write-Verbose "Skipping as it doesn't support '$schemaScopeType'"
            continue
        }

        $children = Get-ObjectProperty $item 'Children'
        $apiVersion = _getEntryApiVersion $item
        $uri = _getEntryUri $item

        # batch request id cannot contain '\' character
        $id = $outputFileName -replace '\\', '/'

        # to avoid duplicated ids in batch request if there are multiple $ExportSchema items with the same path
        $id = _randomizeRequestId $id

        Write-Verbose "Adding request '$uri' with id '$id' to the batch"

        $request = New-GraphBatchRequest -Url $uri -Id $id -header @{ ConsistencyLevel = 'eventual' }

        _queueRequest -request $request -apiVersion $apiVersion

        # track children for later processing
        if ($children) {
            $script:childrenToProcess.Add(@{
                Children = $children
                BasePath = Join-Path -Path $Path -ChildPath $item.Path
                ParentPath = $item.Path
            })
        }
    }

    # execute root level batch requests
    _executeBatchRequests -batchRequestStableApi ([ref]$batchRequestStableApi) -batchRequestBetaApi ([ref]$batchRequestBetaApi) -results ([ref]$results) -requestedExportSchema $requestedExportSchema

    # process children recursively
    while ($script:childrenToProcess.Count -gt 0) {
        $currentBatch = $script:childrenToProcess
        $script:childrenToProcess = [System.Collections.Generic.List[Object]]::new()

        foreach ($childGroup in $currentBatch) {
            Write-Verbose "Looking for results for parent with path '$($childGroup.ParentPath)'"

            $parentResult = $results | Where-Object {
                $normalizedRequestId = _normalizeRequestId $_.RequestId
                $normalizedRequestId -eq ($childGroup.BasePath -replace "\\", "/") -or
                $normalizedRequestId -like ("$($childGroup.ParentPath)*" -replace "\\", "/")
            }

            if (!$parentResult) {
                Write-Verbose "Parent '$($childGroup.ParentPath)' doesn't contain any data, skipping children retrieval"
                continue
            }

            # there can be multiple parent items with same Path, remove duplicates just in case
            $parentIds = $parentResult.Id | select -Unique
            Write-Verbose "Processing children results for parent '$($childGroup.ParentPath)' ($($parentIds.count))"

            _processChildrenRecursive -schemaItems $childGroup.Children -basePath $childGroup.BasePath -parentIds $parentIds
        }

        # execute batch requests for this level
        _executeBatchRequests -batchRequestStableApi ([ref]$batchRequestStableApi) -batchRequestBetaApi ([ref]$batchRequestBetaApi) -results ([ref]$results) -requestedExportSchema $requestedExportSchema
    }
    #endregion process all schema items recursively

    #region output results
    foreach ($item in $results) {
        if (!(Get-ObjectProperty $item 'Id')) {
            $itemId = ($item.RequestId -split "/")[-1]
            # remove the random number added to avoid duplicated ids in batch requests
            $itemId = _normalizeRequestId $itemId

            Write-Verbose ($item | convertto-json -WarningAction SilentlyContinue)
            Write-Verbose "Result without 'id' property, using '$itemId' instead (RequestId '$($item.RequestId)')!"
        } else {
            $itemId = $item.id
        }

        if ("$itemId" -match '[\\/]|^\.\.?$') {
            Write-Error "Skipping '$itemId' (request '$($item.RequestId)'): the id contains a path separator or is a relative path segment."
            continue
        }

        if (!$item.RequestId) {
            $item
            Write-Warning "Item without RequestId. Shouldn't happen!"
        }

        $outputFileName = $item.RequestId -replace "/", "\"
        # remove the random number added to avoid duplicated ids in batch requests
        $outputFileName = _normalizeRequestId $outputFileName

        if ($outputFileName -notmatch "\.json$") {
            $outputFileName = Join-Path (Join-Path -Path $outputFileName -ChildPath $itemId) -ChildPath "$itemId.json"
        }

        $item | Select-Object * -ExcludeProperty RequestId | ConvertTo-Json -depth 100 | Out-File (New-Item -Path $outputFileName -Force)
    }
    #endregion output results
}
