function New-GraphBatchRequest {
    <#
    .SYNOPSIS
    Function creates PSObject(s) representing request(s) that can be used in Graph Api batching.

    .DESCRIPTION
    Function creates PSObject(s) representing request(s) that can be used in Graph Api batching.

    PSObject will look like this:
        @{
            Method  = "GET"
            URL     = "/identityProviders/Google-OAUTH"
            Id      = "idpInfo"
        }

        Method = method that will be used when sending the request
        URL = Graph API URL that should be requested
        Id = ID that has to be unique across the batch requests

    .PARAMETER method
    Request method.

    Possible values: 'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'.

    By default GET.

    .PARAMETER url
    Request URL in relative form like "/identityProviders/Google-OAUTH" a.k.a. without the "https://graph.microsoft.com/<apiVersion>" prefix (API version is specified when the batch is invoked).

    When the 'placeholder' parameter is specified, for each value it contains, new request url will be generated with such value used instead of the '<placeholder>' string.

    .PARAMETER placeholder
    Array of items (string, integers, ..) that will be used in the request url ('url' parameter) instead of the "<placeholder>" string.

    .PARAMETER header
    Header that should be added to each request in the batch.

    .PARAMETER body
    Body that should be added to each request in the batch.

    .PARAMETER id
    Id of the request.
    If created request will be invoked via 'Invoke-GraphBatchRequest' function, this Id will be saved in the returned object's 'RequestId' property.
    Can only be specified when 'url' parameter contains just one value.
    If url with placeholder is used, suffix "_<randomnumber>" will be added to each generated request id. This way each one is unique and at the same time you are able to filter the request results based on it in case you merge multiple different requests in one final batch.

    Cannot contain "\" character, because Invoke-MgRestMethod used for sending request automatically tries to convert the returned JSON back and it fails because of this special character.

    By default random-generated-number.

    .PARAMETER placeholderAsId
    Switch to use current 'placeholder' value used in the request URL as an request ID.

    BEWARE that request ID has to be unique across the pools of all batch requests, therefore use this switch with a caution!

    .EXAMPLE
    $batchRequest = New-GraphBatchRequest -url "identityProviders", "identity/apiConnectors"

    Invoke-GraphBatchRequest -batchRequest $batchRequest

    Creates batch request object containing both urls & run it.

    .EXAMPLE
    $flowId = (Invoke-MgGraphRequest -Uri "identity/authenticationEventsFlows").value.id

    New-GraphBatchRequest -url "identity/authenticationEventsFlows/<placeholder>/conditions" -placeholder $flowId | Invoke-GraphBatchRequest

    Creates batch request object containing dynamically generated urls for every user flow id & run it.

    .NOTES
    Author: @AndrewZtrhgf

    HomePage: https://doitpshway.com

    HomeModule: MSGraphStuff

    https://learn.microsoft.com/en-us/graph/json-batching
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [ValidateNotNullOrEmpty()]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS')]
        [string] $method = "GET",

        [Parameter(Mandatory = $true)]
        [Alias("urlWithPlaceholder")]
        [string[]] $url,

        $placeholder,

        [hashtable] $header,

        [hashtable] $body,

        [Parameter(ParameterSetName = "Id")]
        [ValidateScript( {
            if ($_ -like "*\*") {
                Write-Warning "Id ($_) can't contain '\' character!"
                return
            } else {
                $true
            }
        })]
        [string] $id,

        [Parameter(ParameterSetName = "PlaceholderAsId")]
        [switch] $placeholderAsId
    )

    #region validity checks
    if ($id -and @($url).count -gt 1) {
        Write-Warning "'id' parameter cannot be used with multiple urls"
        return
    }

    if ($placeholder -and $url -notlike "*<placeholder>*") {
        Write-Warning "You have specified 'placeholder' parameter, but 'url' parameter doesn't contain string '<placeholder>' for replace."
        return
    }

    if (!$placeholder -and $url -like "*<placeholder>*") {
        Write-Warning "You have specified 'url' with '<placeholder>' in it, but not the 'placeholder' parameter itself."
        return
    }

    if ($placeholderAsId -and !$placeholder) {
        Write-Warning "'placeholderAsId' parameter cannot be used without specifying 'placeholder' parameter"
        return
    }

    if ($placeholderAsId -and $placeholder -and @($url).count -gt 1) {
        Write-Warning "'placeholderAsId' parameter cannot be used with multiple urls"
        return
    }

    if ($placeholderAsId) {
        $placeholder | % {
            if ($_ -like "*\*") {
                Write-Warning "'placeholderAsId' parameter cannot be used when 'placeholder' contains '\' character (value: '$_')!"
                return
            }
        }
    }

    # method is case sensitive!
    $method = $method.ToUpper()
    #endregion validity checks

    if ($placeholder) {
        $url = $placeholder | % {
            $p = $_

            $url | % {
                $_ -replace "<placeholder>", $p
            }
        }
    }

    $index = 0

    $url | % {
        # fix common mistake where there are multiple following slashes
        $currentUrl = $_ -replace "(?<!^https:)/{2,}", "/"

        if ($currentUrl -like "http*" -or $currentUrl -like "*/beta/*" -or $currentUrl -like "*/v1.0/*" -or $currentUrl -like "*/graph.microsoft.com/*") {
            Write-Warning "url '$currentUrl' has to be in the relative form (without the whole 'https://graph.microsoft.com/<apiversion>' part)!"
            return
        }

        $property = [ordered]@{
            method = $method
            URL    = $currentUrl
        }

        if ($id) {
            if ($placeholder -and $placeholder.count -gt 1) {
                $property.id = ($id + "_" + (Get-Random))
            } else {
                $property.id = $id
            }
        } elseif ($placeholderAsId -and $placeholder) {
            $property.id = @($placeholder)[$index]
        } else {
            $property.id = Get-Random
        }

        if ($header) {
            $property.headers = $header
        }

        if ($body) {
            $property.body = $body
        }

        New-Object -TypeName PSObject -Property $property

        ++$index
    }
}
