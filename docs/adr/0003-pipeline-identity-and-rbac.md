# 0003 - Pipeline Identity and RBAC

## Status
Accepted

## Context
The GitLab pipeline needs a non-human identity to authenticate to Azure and 
manage infrastructure via Terraform. The identity must have sufficient 
permissions to create and manage resources across environments without storing 
static credentials.

## Decision

### Pipeline Identity
Use app registration + service principal as the pipeline identity.
Use OIDC federation (not static secrets) for authentication with GitLab.com 
as the issuer, scoped to the master branch. No static credentials are stored 
anywhere — OIDC tokens are short-lived and generated per pipeline run.

### RBAC Role Assignments
Contributor role assigned at subscription scope as a temporary solution to 
unblock the initial build. Intent is to tighten to resource-group scope once 
the dev environment is stable.

Storage Blob Data Contributor scoped to the storage account permanently. 
State file access does not require broader storage permissions.

Key Vault will use the Azure RBAC access model rather than Vault Access 
Policies. This aligns with the project-wide RBAC approach, provides granular 
permissions at the secret, key, and certificate level, and keeps all permission 
management in one place across subscription, resource group, and individual 
resource scopes. Key Vault role assignments will be documented here as 
Phase 4 progresses.

### Secrets Management
Azure Key Vault is the primary secrets manager through Phases 4-7.
Public network access disabled — VNet only via private endpoint in snet-infra.
Key Vault name: lxv-kv-01-capstone-eus (globally unique, hyphens permitted 
per Microsoft docs).
Soft delete enabled with 7-day retention for lab environment.
Purge protection disabled to allow immediate purge during active development — 
revisit before any production use.
HashiCorp Vault deferred to post-Phase 7 — to be integrated once real 
application secrets exist and the full platform is operational.

## Consequences
No static credentials stored anywhere — OIDC tokens are short-lived and 
scoped per pipeline run.

Subscription-scoped Contributor is broader than least-privilege — accepted 
risk for the build phase. 

### Revisit trigger: tighten Contributor Scope
tighten to resource-group scope once rg-01-capstone-dev-eus and any additional environment resource groups 
are stable.

Storage Blob Data Contributor intentionally narrow — state file access does 
not require broader storage permissions.

Purge protection disabled means Key Vault and its contents can be permanently 
deleted before the retention window expires. Acceptable for a lab environment. 
Must be enabled before any production use.

Vault deferral means Key Vault handles all secrets through the build phase. 
The operational burden of running and maintaining a Vault VM is not justified 
until real multi-service secrets exist and the platform is fully operational.

### Revisit consequence: incorporating Vault
Future role assignments for Key Vault, Bastion, and team contributors will 
be added to this ADR as Phase 4 progresses.

## Exceptions
Document approved exceptions to the decision or standard.
Explain why each exception is required and any constraints associated with it.
If no exceptions exist, state:

None.

## References
Include relevant documentation, standards, specifications, vendor documentation, or other supporting material.

## Appendix
Include supporting information that is useful to the ADR but not required to understand the primary decision.
Examples may include:
Resource mappings
Naming tables
Configuration examples
Diagrams
Implementation notes
Provider-specific information
