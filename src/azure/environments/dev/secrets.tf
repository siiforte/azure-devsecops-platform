module "secrets" {
  source = "../../modules/secrets"

  name                       = var.key_vault_name
  resource_group_name        = azurerm_resource_group.capstone_rg.name
  location                   = var.azure_region
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  admin_ip_addresses         = var.admin_ip_addresses
  tags                       = local.common_tags
}