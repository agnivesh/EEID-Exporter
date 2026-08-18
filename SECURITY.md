# Security Policy

This project reads a Microsoft Entra External ID tenant's configuration over the
Microsoft Graph API and writes it to local JSON files. It never writes to a tenant.
A vulnerability here would most likely be: the module requesting broader Graph
scopes than it needs, mishandling the token/credential a caller supplies, or
`Publish-EEIDBackup` exposing exported data in transit or at rest.

## Reporting a Vulnerability

Please report security issues privately using
[GitHub's private vulnerability reporting](../../security/advisories/new) for this
repository, rather than opening a public issue.

Include:

- The affected version/commit
- Steps to reproduce, and the impact you'd expect (e.g. scope over-request,
  credential leakage, data exposure)
- Whether the issue requires a specific tenant configuration to trigger

You should get an initial response within a few days. Please allow time to
investigate and release a fix before any public disclosure.

## Scope

In scope: the PowerShell module itself (`src/`) and the example CI/CD workflows
(`.github/workflows/`, `pipelines/`).

Out of scope: vulnerabilities in Microsoft Graph, the `Microsoft.Graph.Authentication`,
`Az.Storage`, or `AWS.Tools.S3` modules themselves -- report those to Microsoft or
AWS directly.
