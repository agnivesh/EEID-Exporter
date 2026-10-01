@{
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # This module intentionally uses aliases like % and ? in ported batch-request
        # internals to stay consistent with the upstream pattern they were adapted from.
        'PSAvoidUsingCmdletAliases',

        # Write-Host is used deliberately for interactive progress output during a
        # long-running export -- it must not be captured on the success stream the
        # way Write-Output would be, since that stream feeds the JSON files written
        # to disk.
        'PSAvoidUsingWriteHost',

        # Get-EEIDRequiredScopes returns a collection by design; the plural noun
        # accurately describes that.
        'PSUseSingularNouns',

        # New-GraphBatchRequest and New-FinalUri are pure functions -- they build and
        # return an object/string with no side effects -- despite the New- verb that
        # normally implies state change. Adding ShouldProcess to a pure constructor
        # would be misleading, not safer.
        'PSUseShouldProcessForStateChangingFunctions',

        # Every flagged case here was manually verified to be a false positive:
        # ArgumentCompleter script blocks must accept all five positional parameters
        # of that delegate signature even when unused in the body; [ref] parameters
        # (accessed as $paramName.Value) and parameters only read inside a
        # conditional block aren't tracked correctly by this rule's static analysis.
        'PSReviewUnusedParameter'
    )
}
