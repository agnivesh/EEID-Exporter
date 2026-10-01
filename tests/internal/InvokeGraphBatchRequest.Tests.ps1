BeforeAll {
    . "$PSScriptRoot/../../src/internal/New-GraphBatchRequest.ps1"
    . "$PSScriptRoot/../../src/internal/Invoke-GraphBatchRequest.ps1"

    function New-Response {
        param($Id, $Status = 200, $Body = @{ value = @(@{ id = 'item' }) }, $Headers = @{})
        [pscustomobject]@{ id = $Id; status = $Status; headers = $Headers; body = [pscustomobject]$Body }
    }

    Mock Start-Sleep {}
}

Describe 'Invoke-GraphBatchRequest' {
    Context 'server-side errors' {
        It 'retries a 503 response and returns the data once it succeeds' {
            $script:calls = 0
            Mock Invoke-MgRestMethod {
                $script:calls++
                $status = if ($script:calls -eq 1) { 503 } else { 200 }
                [pscustomobject]@{ responses = @(New-Response -Id 'flows' -Status $status) }
            }

            $result = Invoke-GraphBatchRequest -batchRequest (New-GraphBatchRequest -Url 'domains' -Id 'flows') 6>$null

            $result.RequestId | Should -Be 'flows'
            Should -Invoke Invoke-MgRestMethod -Times 2 -Exactly
            Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1 }
        }

        It 'gives up after 5 retries and reports an error' {
            Mock Invoke-MgRestMethod {
                [pscustomobject]@{ responses = @(New-Response -Id 'flows' -Status 503 -Body @{ error = @{ message = 'down' } }) }
            }

            $null = Invoke-GraphBatchRequest -batchRequest (New-GraphBatchRequest -Url 'domains' -Id 'flows') `
                -separateErrors -ErrorAction SilentlyContinue -ErrorVariable batchErrors 6>$null

            Should -Invoke Invoke-MgRestMethod -Times 6 -Exactly
            $batchErrors | Should -HaveCount 1
            $batchErrors[0].Exception.Message | Should -BeLike '*Giving up after 5 retries*'
        }
    }

    Context 'throttling' {
        It 'waits for Retry-After even when another request in the chunk is paginated' {
            $script:throttled = $false
            Mock Invoke-MgRestMethod {
                $urls = ($Body | ConvertFrom-Json).requests
                $responses = foreach ($request in $urls) {
                    switch ($request.url) {
                        'throttled' {
                            if ($script:throttled) { New-Response -Id $request.id }
                            else { $script:throttled = $true; New-Response -Id $request.id -Status 429 -Headers @{ 'Retry-After' = '7' } }
                        }
                        'paged' {
                            New-Response -Id $request.id -Body @{
                                value             = @(@{ id = 'p1' })
                                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/paged2'
                            }
                        }
                        default { New-Response -Id $request.id -Body @{ value = @(@{ id = 'p2' }) } }
                    }
                }
                [pscustomobject]@{ responses = @($responses) }
            }

            $batch = @(
                New-GraphBatchRequest -Url 'throttled' -Id 'throttled'
                New-GraphBatchRequest -Url 'paged' -Id 'paged'
            )
            $result = Invoke-GraphBatchRequest -batchRequest $batch 6>$null

            Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 7 }
            ($result | Where-Object RequestId -eq 'throttled') | Should -Not -BeNullOrEmpty
            ($result | Where-Object RequestId -eq 'paged').id | Should -Be 'p1', 'p2'
        }
    }
}
