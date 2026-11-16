output "id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.key_vault.id
}

output "name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.key_vault.name
}

output "vault_uri" {
  description = "Key Vault URI for secret access."
  value       = azurerm_key_vault.key_vault.vault_uri
}