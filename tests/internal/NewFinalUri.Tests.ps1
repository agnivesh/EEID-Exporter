BeforeAll {
    . "$PSScriptRoot/../../src/internal/ConvertTo-QueryString.ps1"
    . "$PSScriptRoot/../../src/internal/ConvertFrom-QueryString.ps1"
    . "$PSScriptRoot/../../src/internal/New-FinalUri.ps1"
}

Describe 'New-FinalUri' {
    It 'returns the bare relative uri when no filters are given' {
        # System.UriBuilder treats a single path segment with no "/" as a hostname,
        # so it lower-cases it and appends a trailing "/" -- same behavior the
        # upstream EntraExporter project relies on for its own bare single-segment
        # GraphUris (e.g. 'organization', 'domains'). Graph's OData routing is
        # case-insensitive on path segments and tolerant of the trailing slash.
        New-FinalUri -RelativeUri 'identityProviders' | Should -Be 'identityproviders/'
    }

    It 'appends a $select query parameter' {
        $result = New-FinalUri -RelativeUri 'users' -Select 'id', 'displayName'
        $result | Should -Match '\$select=id%2CdisplayName'
    }

    It 'appends a $filter query parameter' {
        $result = New-FinalUri -RelativeUri 'users' -Filter "onPremisesSyncEnabled ne true"
        $result | Should -Match '\$filter='
    }

    It 'merges QueryParameters with an existing query string on the uri' {
        $result = New-FinalUri -RelativeUri 'identity/authenticationEventsFlows?$top=5' -QueryParameters @{ '$expand' = 'onInteractiveAuthFlowStart' }
        $result | Should -Match '\$top=5'
        $result | Should -Match '\$expand=onInteractiveAuthFlowStart'
    }

    It 'preserves <placeholder> tokens unescaped for later substitution' {
        $result = New-FinalUri -RelativeUri 'identity/authenticationEventsFlows/<placeholder>/conditions'
        $result | Should -Match '<placeholder>'
    }
}
