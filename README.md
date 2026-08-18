# EntraExternalIDExporter

> [!WARNING]
> Early-stage and not yet verified against a live tenant. Every permission this
> module requests is read-only (`*.Read.All` scopes) and it never writes to your
> tenant, but the schema, permission list, and CI/CD examples haven't been run
> against a real External ID tenant yet. Use with care, and test against a
> throwaway tenant before relying on this for a real backup.

A PowerShell module that backs up a Microsoft Entra External ID external (CIAM)
tenant's configuration to local JSON files, so it can be version-controlled and
kept for reference like any other infrastructure-as-code artifact.

Based on [microsoft/EntraExporter](https://github.com/microsoft/EntraExporter),
which backs up a *workforce* Entra tenant. An external tenant is a structurally
different kind of Microsoft Entra tenant -- used to publish apps to consumers and
business customers via `*.ciamlogin.com` -- and this module is scoped specifically to
it. It intentionally does not export anything workforce-only (Entitlement
Management, Access Reviews, PIM, Application Proxy, Teams/SharePoint admin settings,
on-prem sync, device join, Azure RBAC): none of that exists in an external tenant.

Export-only. This module never writes to your tenant -- it only reads and produces
JSON files. There is no restore/import capability.

## What gets exported

By default (`-Type Config`, the default):

- User flows (`identity/authenticationEventsFlows`) -- the core CIAM artifact:
  sign-up/sign-in handler configuration and conditions
- Identity providers (social, custom OIDC, Microsoft Entra federation)
- API connectors and custom authentication extensions
- Organisation profile and company branding
- Domains, including custom URL domain configuration
- Authorisation, external identities, token, claims-mapping, and app-management
  policies
- Authentication methods (email OTP, SMS)
- Cross-tenant access policy (for Microsoft Entra ID federation as an IdP)
- Fraud protection and web application firewall provider integrations
- Conditional Access policies, named locations, authentication contexts
- Directory roles and role assignments (admin accounts -- everyone else defaults to
  low-privilege in an external tenant)

Opt-in via `-Type` (or `-All`), because of volume:

- `Applications` -- app registrations and their policies
- `ServicePrincipals` -- enterprise applications, including SAML apps
- `Groups` -- admin/app-role groups (customer accounts aren't grouped)
- `Users` -- both customer and admin accounts; each user's `identities` property
  shows whether they signed up with a local account or a federated identity provider

Run `(Get-Command Export-EEID | Select-Object -Expand Parameters)['Type'].Attributes.ValidValues`
to see the current list, or check `src/Get-EEIDDefaultSchema.ps1` directly.

## Installing

Not yet published to the PowerShell Gallery. Import from a local clone:

```powershell
Import-Module ./src/EntraExternalIDExporter.psd1
```

## Connecting and exporting

```powershell
Connect-EEIDExporter -TenantId <your-ciam-tenant-id>
Export-EEID -Path './EEIDBackup'
```

`Connect-EEIDExporter` requests only the delegated scopes needed for the `-Type`
you're exporting.

For a full export:

```powershell
Export-EEID -Path './EEIDBackup' -All
```

Or pick specific types:

```powershell
Export-EEID -Path './EEIDBackup' -Type UserFlows, Applications
```

### App-only / unattended authentication

`Connect-EEIDExporter` only supports interactive delegated sign-in. For unattended
runs, call `Connect-MgGraph` directly before `Export-EEID` -- it only needs an active
`Get-MgContext`, however that context was established:

```powershell
# Certificate
Connect-MgGraph -ClientId <app-id> -TenantId <tenant-id> -CertificateThumbprint <thumbprint>

# Client secret
Connect-MgGraph -ClientId <app-id> -TenantId <tenant-id> -ClientSecretCredential (Get-Credential)

# Managed identity (running on an Azure resource)
Connect-MgGraph -Identity
```

Required application permissions, matching the scopes `Get-EEIDRequiredScopes` would
request in delegated mode: `Organization.Read.All`, `Domain.Read.All`,
`IdentityUserFlow.Read.All`, `IdentityProvider.Read.All`, `APIConnectors.Read.All`,
`CustomAuthenticationExtension.Read.All`, `Application.Read.All`, `Policy.Read.All`,
`Policy.Read.PermissionGrant`, `RoleManagement.Read.Directory`, plus
`User.Read.All`/`Group.Read.All` if exporting those opt-in types.

## CI/CD authentication (workload identity federation, no stored secrets)

Both examples below authenticate the pipeline to Microsoft Graph via OIDC/workload
identity federation rather than a stored client secret.

One-time setup, either platform: register an app in the CIAM tenant, grant it
the application permissions listed above, then add a federated credential to that app
registration (Entra admin center > App registrations > your app > Certificates &
secrets > Federated credentials).

- GitHub Actions: [`.github/workflows/backup-example.yml`](.github/workflows/backup-example.yml)
  uses a federation policy with issuer `https://token.actions.githubusercontent.com`
  and subject `repo:<org>/<repo>:environment:<environment-name>`. The workflow signs
  in via `azure/login` (which mints the OIDC token and sets the environment
  variables `Connect-MgGraph -EnvironmentVariable` reads), then runs `Export-EEID`.
- Azure DevOps: [`pipelines/azure-pipelines-backup-example.yml`](pipelines/azure-pipelines-backup-example.yml)
  uses a workload identity federation service connection; an `AzureCLI@2` task mints
  a Graph-scoped access token which is passed to `Connect-MgGraph -AccessToken`.

## Publishing backups to cloud storage

`Publish-EEIDBackup` uploads an `Export-EEID` output folder to Azure Blob Storage
and/or S3, using whichever Azure/AWS credential context you already have active (so
it works the same with an interactive login, a certificate, a managed identity, or
workload identity federation).

```powershell
# Azure Blob Storage -- requires Install-Module Az.Storage
Publish-EEIDBackup -Path ./EEIDBackup -AzureStorageAccount myacct -Container eeid-backups -Prefix (Get-Date -Format 'yyyy-MM-dd')

# S3 -- requires Install-Module AWS.Tools.S3
Publish-EEIDBackup -Path ./EEIDBackup -S3Bucket my-eeid-backups -S3Region eu-west-1

# Both at once
Publish-EEIDBackup -Path ./EEIDBackup -AzureStorageAccount myacct -Container eeid-backups -S3Bucket my-eeid-backups
```

Required permissions on the target: Azure Storage `Storage Blob Data Contributor`
role on the storage account, or an S3 bucket policy allowing `s3:PutObject` for the
identity running the pipeline.

Both providers encrypt everything at rest by default. Azure Storage encrypts
automatically with Microsoft-managed keys, nothing to configure. For S3,
`Publish-EEIDBackup` explicitly sets `-ServerSideEncryption AES256` on every upload,
so encryption is guaranteed regardless of the target bucket's own default-encryption
setting. Customer-managed keys and client-side encryption aren't supported --
open an issue if your compliance requirements need them.

## Development

```powershell
Install-Module PSScriptAnalyzer, Pester -Scope CurrentUser
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path ./tests
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).
Found a security issue? See [SECURITY.md](SECURITY.md) instead of opening a public issue.

## License

Apache License 2.0, see [LICENSE](LICENSE).
