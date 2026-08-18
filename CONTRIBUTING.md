# Contributing

## Development setup

Requires PowerShell 7+.

```powershell
Install-Module PSScriptAnalyzer, Pester -Scope CurrentUser
Import-Module ./src/EntraExternalIDExporter.psd1
```

## Before opening a PR

```powershell
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path ./tests
```

Both must be clean/green -- CI enforces this on every PR. If a PSScriptAnalyzer
finding is a false positive rather than something to fix, add it to
`PSScriptAnalyzerSettings.psd1`'s `ExcludeRules` with a comment explaining why,
rather than leaving it unaddressed.

If you touch the GitHub Actions workflows, also run:

```sh
actionlint .github/workflows/*.yml
zizmor .github/workflows/
```

## Adding a new export type

New Graph endpoints belong in `src/Get-EEIDDefaultSchema.ps1`, following the
existing entries: `GraphUri`, `Path`, `Tag`, and at least one of
`DelegatedPermission`/`ApplicationPermission`. Add or extend a test in
`tests/Get-EEIDDefaultSchema.Tests.ps1` if you're introducing a new `Tag` --
it needs to exist in the `ObjectType` enum in
`src/EntraExternalIDExporterEnums.ps1` too.

Please don't add anything that only exists in workforce Entra tenants
(devices, Teams/SharePoint admin settings, PIM, Entitlement Management,
Application Proxy, Azure RBAC) -- this module is scoped specifically to
External ID external (CIAM) tenants, which don't have those features.

## Commit style

Imperative mood, one logical change per commit (e.g. "Add fraud protection
provider export", not "changes" or "wip").

## Reporting bugs / requesting features

Open a GitHub issue. For security issues, see [SECURITY.md](SECURITY.md) instead.
