BeforeAll {
    . "$PSScriptRoot/../../src/internal/ConvertTo-QueryString.ps1"
    . "$PSScriptRoot/../../src/internal/ConvertFrom-QueryString.ps1"
}

Describe 'ConvertTo-QueryString' {
    It 'converts a hashtable into a query string' {
        $result = ConvertTo-QueryString @{ '$select' = 'id,displayName' }
        $result | Should -Be '$select=id%2CdisplayName'
    }

    It 'URL-encodes values' {
        $result = ConvertTo-QueryString @{ '$filter' = "displayName eq 'a b'" }
        $result | Should -Match 'a\+b'
    }
}

Describe 'ConvertFrom-QueryString' {
    It 'round-trips simple query strings back into a hashtable' {
        $result = ConvertFrom-QueryString 'name=path%2Ffile.json&index=10' -AsHashtable
        $result['name'] | Should -Be 'path/file.json'
        $result['index'] | Should -Be '10'
    }

    It 'strips a leading question mark' {
        $result = ConvertFrom-QueryString '?a=1' -AsHashtable
        $result['a'] | Should -Be '1'
    }
}
