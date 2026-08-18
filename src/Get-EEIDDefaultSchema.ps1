<#
 .Synopsis
  Gets the default export schema definition for a Microsoft Entra External ID
  external (CIAM) tenant.

 .Description
  Defines every Microsoft Graph endpoint this module can back up and the order in
  which they are exported. Unlike a workforce Entra tenant, an external tenant has
  no Entitlement Management, Access Reviews, PIM, Application Proxy, Teams/SharePoint
  admin settings, on-prem sync, device join, or Azure RBAC surface -- none of that is
  modeled here because there is nothing there to export.

  User flows (`identity/authenticationEventsFlows`) are part of the default 'Config'
  export rather than opt-in, because they are the primary CIAM artifact.

 .Example
  Get-EEIDDefaultSchema
#>

function Get-EEIDDefaultSchema {
    $tenantId = (Get-MgContext).TenantId
    return @(
        # Organization
        @{
            GraphUri              = 'organization'
            Path                  = 'Organization/Organization.json'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Organization.Read.All'
            ApplicationPermission = 'Organization.Read.All'
        },
        @{
            GraphUri              = 'organization/{0}/branding/localizations' -f $tenantId
            Path                  = 'Organization/Branding/Localizations.json'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Organization.Read.All'
            ApplicationPermission = 'Organization.Read.All'
        },
        @{
            GraphUri              = 'domains'
            Path                  = 'Domains'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Domain.Read.All'
            ApplicationPermission = 'Domain.Read.All'
        },

        # User flows -- the core CIAM artifact
        @{
            GraphUri              = 'identity/authenticationEventsFlows'
            QueryParameters       = @{ '$expand' = 'onInteractiveAuthFlowStart,onAuthenticationMethodLoadStart,onAttributeCollection,onAttributeCollectionStart,onAttributeCollectionSubmit,onUserCreateStart' }
            Path                  = 'Identity/AuthenticationEventsFlows'
            Tag                   = @('All', 'Config', 'UserFlows')
            DelegatedPermission   = 'IdentityUserFlow.Read.All'
            ApplicationPermission = 'IdentityUserFlow.Read.All'
            Children              = @(
                @{
                    GraphUri              = 'identity/authenticationEventsFlows/<placeholder>/conditions'
                    Path                  = 'Conditions'
                    Tag                   = @('All', 'Config', 'UserFlows')
                    DelegatedPermission   = 'IdentityUserFlow.Read.All'
                    ApplicationPermission = 'IdentityUserFlow.Read.All'
                }
            )
        },
        @{
            GraphUri              = 'identity/userFlowAttributes'
            Path                  = 'Identity/UserFlowAttributes'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config', 'UserFlows')
            DelegatedPermission   = 'IdentityUserFlow.Read.All'
            ApplicationPermission = 'IdentityUserFlow.Read.All'
            IgnoreError           = 'The feature self service sign up is not enabled for the tenant'
        },

        # Identity providers & sign-in security
        @{
            GraphUri              = 'identityProviders'
            Path                  = 'IdentityProviders'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'IdentityProvider.Read.All'
            ApplicationPermission = 'IdentityProvider.Read.All'
        },
        @{
            GraphUri              = 'identity/apiConnectors'
            Path                  = 'Identity/APIConnectors'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'APIConnectors.Read.All'
            ApplicationPermission = 'APIConnectors.Read.All'
            IgnoreError           = 'The feature self service sign up is not enabled for the tenant'
        },
        @{
            GraphUri              = 'identity/customAuthenticationExtensions'
            Path                  = 'Identity/CustomAuthenticationExtensions'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'CustomAuthenticationExtension.Read.All'
            ApplicationPermission = 'CustomAuthenticationExtension.Read.All'
        },
        @{
            GraphUri              = 'identity/fraudProtectionProviders'
            Path                  = 'Identity/FraudProtectionProviders'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Application.Read.All'
            ApplicationPermission = 'Application.Read.All'
        },
        @{
            GraphUri              = 'identity/webApplicationFirewallProviders'
            Path                  = 'Identity/WebApplicationFirewallProviders'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Application.Read.All'
            ApplicationPermission = 'Application.Read.All'
        },

        # Policies
        @{
            GraphUri              = 'policies/authorizationPolicy'
            Path                  = 'Policies/AuthorizationPolicy'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/externalIdentitiesPolicy'
            Path                  = 'Policies/ExternalIdentitiesPolicy'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/permissionGrantPolicies'
            Path                  = 'Policies/PermissionGrantPolicies'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.PermissionGrant'
            ApplicationPermission = 'Policy.Read.PermissionGrant'
        },
        @{
            GraphUri              = 'policies/tokenIssuancePolicies'
            Path                  = 'Policies/TokenIssuancePolicy'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/tokenLifetimePolicies'
            Path                  = 'Policies/TokenLifetimePolicy'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/claimsMappingPolicies'
            Path                  = 'Policies/ClaimsMappingPolicy'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/defaultAppManagementPolicy'
            Path                  = 'Policies/DefaultAppManagementPolicy'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/appManagementPolicies'
            Path                  = 'Policies/AppManagementPolicies'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/authenticationMethodsPolicy/authenticationMethodConfigurations/email'
            Path                  = 'Policies/AuthenticationMethodsPolicy/AuthenticationMethodConfigurations/Email.json'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/authenticationMethodsPolicy/authenticationMethodConfigurations/sms'
            Path                  = 'Policies/AuthenticationMethodsPolicy/AuthenticationMethodConfigurations/SMS.json'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/crossTenantAccessPolicy'
            Path                  = 'Policies/CrossTenantAccessPolicy'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/crossTenantAccessPolicy/default'
            Path                  = 'Policies/CrossTenantAccessPolicy/Default'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'policies/crossTenantAccessPolicy/partners'
            Path                  = 'Policies/CrossTenantAccessPolicy/Partners'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },

        # Conditional Access
        @{
            GraphUri              = 'identity/conditionalAccess/policies'
            Path                  = 'Identity/Conditional/AccessPolicies'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config', 'ConditionalAccess')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'identity/conditionalAccess/namedLocations'
            Path                  = 'Identity/Conditional/NamedLocations'
            Tag                   = @('All', 'Config', 'ConditionalAccess')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },
        @{
            GraphUri              = 'identity/conditionalAccess/authenticationContextClassReferences'
            Path                  = 'Identity/Conditional/AuthenticationContexts'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config', 'ConditionalAccess')
            DelegatedPermission   = 'Policy.Read.All'
            ApplicationPermission = 'Policy.Read.All'
        },

        # Roles (admin accounts -- all other users default to low-privilege)
        @{
            GraphUri              = 'directoryRoles'
            Path                  = 'DirectoryRoles'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'RoleManagement.Read.Directory'
            ApplicationPermission = 'RoleManagement.Read.Directory'
            Children              = @(
                @{
                    GraphUri              = 'directoryRoles/<placeholder>/members'
                    Select                = 'id, userPrincipalName, displayName'
                    Path                  = 'Members'
                    Tag                   = @('All', 'Config')
                    DelegatedPermission   = 'RoleManagement.Read.Directory'
                    ApplicationPermission = 'RoleManagement.Read.Directory'
                },
                @{
                    GraphUri              = 'directoryRoles/<placeholder>/scopedMembers'
                    Path                  = 'ScopedMembers'
                    Tag                   = @('All', 'Config')
                    DelegatedPermission   = 'RoleManagement.Read.Directory'
                    ApplicationPermission = 'RoleManagement.Read.Directory'
                }
            )
        },
        @{
            GraphUri              = 'roleManagement/directory/roleDefinitions'
            Path                  = 'RoleManagement/Directory/RoleDefinitions'
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'RoleManagement.Read.Directory'
            ApplicationPermission = 'RoleManagement.Read.Directory'
        },
        @{
            GraphUri              = 'roleManagement/directory/roleAssignments'
            Path                  = 'RoleManagement/Directory/RoleAssignments'
            QueryParameters       = @{ '$expand' = 'principal' }
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Config')
            DelegatedPermission   = 'RoleManagement.Read.Directory'
            ApplicationPermission = 'RoleManagement.Read.Directory'
        },

        # Applications (opt-in -- volume)
        @{
            GraphUri              = 'applications'
            Path                  = 'Applications'
            Tag                   = @('All', 'Applications')
            DelegatedPermission   = 'Application.Read.All'
            ApplicationPermission = 'Application.Read.All'
            Children              = @(
                @{
                    GraphUri              = 'applications/<placeholder>/extensionProperties'
                    Path                  = 'ExtensionProperties'
                    Tag                   = @('All', 'Applications')
                    DelegatedPermission   = 'Application.Read.All'
                    ApplicationPermission = 'Application.Read.All'
                },
                @{
                    GraphUri              = 'applications/<placeholder>/owners'
                    Select                = 'id, userPrincipalName, displayName'
                    Path                  = 'Owners'
                    Tag                   = @('All', 'Applications')
                    DelegatedPermission   = 'Application.Read.All'
                    ApplicationPermission = 'Application.Read.All'
                },
                @{
                    GraphUri              = 'applications/<placeholder>/tokenIssuancePolicies'
                    Path                  = 'TokenIssuancePolicies'
                    Tag                   = @('All', 'Applications')
                    DelegatedPermission   = 'Policy.Read.All'
                    ApplicationPermission = 'Policy.Read.All'
                },
                @{
                    GraphUri              = 'applications/<placeholder>/tokenLifetimePolicies'
                    Path                  = 'TokenLifetimePolicies'
                    Tag                   = @('All', 'Applications')
                    DelegatedPermission   = 'Policy.Read.All'
                    ApplicationPermission = 'Policy.Read.All'
                },
                @{
                    GraphUri              = 'applications/<placeholder>/appManagementPolicies'
                    Path                  = 'AppManagementPolicies'
                    Tag                   = @('All', 'Applications')
                    DelegatedPermission   = 'Policy.Read.All'
                    ApplicationPermission = 'Policy.Read.All'
                }
            )
        },

        # Service Principals (opt-in -- covers SAML enterprise-app registrations too)
        @{
            GraphUri              = 'servicePrincipals'
            Path                  = 'ServicePrincipals'
            Tag                   = @('All', 'ServicePrincipals')
            DelegatedPermission   = 'Application.Read.All'
            ApplicationPermission = 'Application.Read.All'
            Children              = @(
                @{
                    GraphUri              = 'servicePrincipals/<placeholder>/appRoleAssignments'
                    Path                  = 'AppRoleAssignments'
                    Tag                   = @('All', 'ServicePrincipals')
                    DelegatedPermission   = 'Application.Read.All'
                    ApplicationPermission = 'Application.Read.All'
                },
                @{
                    GraphUri              = 'servicePrincipals/<placeholder>/appRoleAssignedTo'
                    Path                  = 'AppRoleAssignedTo'
                    Tag                   = @('All', 'ServicePrincipals')
                    DelegatedPermission   = 'Application.Read.All'
                    ApplicationPermission = 'Application.Read.All'
                },
                @{
                    GraphUri              = 'servicePrincipals/<placeholder>/oauth2PermissionGrants'
                    Path                  = 'Oauth2PermissionGrants'
                    Tag                   = @('All', 'ServicePrincipals')
                    DelegatedPermission   = 'Application.Read.All'
                    ApplicationPermission = 'Application.Read.All'
                },
                @{
                    GraphUri              = 'servicePrincipals/<placeholder>/owners'
                    Select                = 'id, userPrincipalName, displayName'
                    Path                  = 'Owners'
                    Tag                   = @('All', 'ServicePrincipals')
                    DelegatedPermission   = 'Application.Read.All'
                    ApplicationPermission = 'Application.Read.All'
                },
                @{
                    GraphUri              = 'servicePrincipals/<placeholder>/claimsMappingPolicies'
                    Path                  = 'ClaimsMappingPolicies'
                    Tag                   = @('All', 'ServicePrincipals')
                    DelegatedPermission   = 'Policy.Read.All'
                    ApplicationPermission = 'Policy.Read.All'
                }
            )
        },

        # Groups (opt-in -- admin/app-role groups only; customer accounts aren't grouped)
        @{
            GraphUri              = 'groups'
            Path                  = 'Groups'
            QueryParameters       = @{ '$count' = 'true' }
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Groups')
            DelegatedPermission   = 'Group.Read.All'
            ApplicationPermission = 'Group.Read.All'
            Children              = @(
                @{
                    GraphUri              = 'groups/<placeholder>/owners'
                    Select                = 'id, userPrincipalName, displayName'
                    Path                  = 'Owners'
                    Tag                   = @('All', 'Groups')
                    DelegatedPermission   = 'Group.Read.All'
                    ApplicationPermission = 'Group.Read.All'
                },
                @{
                    GraphUri              = 'groups/<placeholder>/members'
                    Select                = 'id, userPrincipalName, displayName'
                    Path                  = 'Members'
                    Tag                   = @('All', 'Groups')
                    DelegatedPermission   = 'Group.Read.All'
                    ApplicationPermission = 'Group.Read.All'
                }
            )
        },

        # Users (opt-in -- covers both customer and admin accounts; the 'identities'
        # property on each user shows local-account vs. federated sign-in)
        @{
            GraphUri              = 'users'
            Path                  = 'Users'
            QueryParameters       = @{ '$count' = 'true'; '$expand' = 'extensions' }
            ApiVersion            = 'beta'
            Tag                   = @('All', 'Users')
            DelegatedPermission   = 'User.Read.All'
            ApplicationPermission = 'User.Read.All'
        }
    )
}
