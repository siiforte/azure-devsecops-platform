# 0005 - Key Vault Design

## Status
Accepted. Amends the Secrets Management network access decision in ADR-0003.

## Context
ADR-0003 chose Azure Key Vault as the platform's secrets manager through Phases 4-7, using the Azure RBAC access model, with HashiCorp Vault deferred until after Phase 7. ADR-0003 also stated that public network access would be disabled, with access only through a private endpoint in snet-infra.

Phase 4 builds the vault as a reusable Terraform module. While designing it, four constraints came up that ADR-0003 did not address:

- **No admin path inside the VNet yet.** Pipelines run on GitLab shared runners on the internet, and there is no self-hosted runner or admin host in the VNet. With public network access fully disabled, nothing outside the VNet can read or write secrets, including the engineer seeding them.
- **Secret values in Terraform end up in state.** Any secret value Terraform creates or reads is stored in plain text in the state file.
- **The pipeline identity cannot assign roles.** It holds Contributor, which can create resources but cannot create role assignments. Granting a managed identity access to the vault requires role-assignment rights.
- **Soft delete reserves the name.** A deleted vault keeps its globally unique name for the retention period, so a destroy-and-rebuild cycle fails unless the vault is purged or recovered.

The first real consumer of the vault is Phase 6: the SSH private key Ansible uses to configure the web VM. Later consumers include TLS certificates for Application Gateway (Phase 7) and application secrets.

## Options Considered

### Network access
1. **Private endpoint only, public access disabled** (ADR-0003). Strongest isolation. Secrets cannot be seeded or read until an in-VNet host exists.
2. **Private endpoint plus a public endpoint locked to an allowlist.** Workloads use the private endpoint. Public access is enabled, but the firewall denies everything except the engineer's admin IP and trusted Azure services.
3. **Public endpoint protected by RBAC only.** Simplest, but any network can reach the vault's data plane.

Selected: option 2 for now, moving to option 1 when an in-VNet admin path exists (see revisit triggers).

### Where secret values come from
1. **Terraform creates the values** (for example `random_password` written to `azurerm_key_vault_secret`). Fully automated, but values are stored in state.
2. **Values are seeded outside Terraform** with the Azure CLI from the allowlisted admin IP. Terraform manages the vault and who can access it, never the values.

Selected: option 2.

## Decision

### Vault configuration
- Name: lxv-kv-01-capstone-eus (globally unique, hyphens permitted per Microsoft docs).
- SKU: Standard.
- Authorization: Azure RBAC model. No access policies.
- Soft delete: 7-day retention (lab environment).
- Purge protection: disabled, so the vault can be destroyed and rebuilt during development. Revisit before any production use.
- Provider feature flags set so a destroyed vault is purged on destroy, allowing the same name to be reused on rebuild.

### Network access
- Private endpoint in snet-infra for workloads inside the VNet.
- Private DNS zone privatelink.vaultcore.azure.net, linked to the VNet. The zone is created in the environment composition, not the module, so later private endpoints can share it.
- Public network access enabled, with the firewall set to deny by default:
  - Allowed: the engineer's admin IP only.
  - Bypass: trusted Azure services.
- The admin IP is supplied as a variable (`TF_VAR_admin_ip` in GitLab CI/CD variables and in a local `*.secrets.tfvars`), never committed to the repository.

### Secrets
- Terraform manages the vault, its network rules, and its role assignments. It never creates or reads secret values, so no secret values are written to state.
- Secrets are seeded and rotated with the Azure CLI from the admin IP. Each seeding step is documented in the build log, without values.
- First secret: the Ansible SSH private key for the web VM. Ansible retrieves it from the vault at run time instead of keeping it on disk.

### Role assignments
All access is granted by role, at the narrowest practical scope:

| Principal | Role | Scope | Purpose |
|---|---|---|---|
| Engineer (user) | Key Vault Secrets Officer | Vault | Seed and rotate secrets |
| Pipeline identity | Role Based Access Control Administrator, conditioned to assign only Key Vault Secrets User | Vault resource group | Lets Terraform grant workloads read access without broader role-assignment rights |
| Workload identities (future runner, web VM if it needs a secret) | Key Vault Secrets User | Vault, or the individual secret | Read only the secrets they need |

The pipeline identity's conditional role assignment is created in bootstrap, because the pipeline cannot grant itself new rights.

### Module interface
The module is single-purpose: it creates the vault, its firewall rules, and its private endpoint. Role assignments and the private DNS zone live in the environment composition.

Inputs: `name`, `resource_group_name`, `location`, `tenant_id`, `sku_name`, `soft_delete_retention_days`, `purge_protection_enabled`, `public_network_access_enabled`, `allowed_ip_addresses`, `private_endpoint_subnet_id`, `private_dns_zone_id`, `tags`.

Outputs: `id`, `name`, `vault_uri`, `private_endpoint_ip`.

## Consequences
Workloads inside the VNet reach the vault privately, and the only public path is a single allowlisted IP. This is weaker than ADR-0003's private-only design, and the difference is temporary and recorded.

No secret value ever appears in Terraform code or state. The trade-off is that seeding and rotation are manual steps, documented in the build log.

The pipeline can grant read access to the vault, and only that role. It still cannot grant itself or anyone else broader permissions.

Pipelines on GitLab shared runners manage the vault through the Azure control plane only. They cannot reach the vault's data plane, which suits the decision that Terraform never touches secret values.

The admin IP is dynamic. When it changes, the variable must be updated and the pipeline re-applied before the vault is reachable again.

Purge protection is disabled, so a deleted vault and its contents can be permanently removed before the retention period ends. Acceptable for a lab environment only.

### Revisit trigger: in-VNet admin path
When a self-hosted GitLab runner exists in snet-runners, move secret seeding and Ansible runs to the runner, remove the admin IP rule, and disable public network access, returning to ADR-0003's private-only design.

### Revisit trigger: audit logging
When a Log Analytics workspace exists, send the vault's audit logs to it through diagnostic settings, so every secret read and write is recorded.

### Revisit trigger: production
Before any production use, enable purge protection, extend soft-delete retention, and give production its own vault.

### Revisit trigger: HashiCorp Vault
Re-evaluate HashiCorp Vault after Phase 7, as stated in ADR-0003.