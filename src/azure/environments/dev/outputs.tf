output "key_vault_uri" {
  description = "Key Vault URI for secret access."
  value       = module.secrets.vault_uri
}

output "web_fqdn" {
  description = "Public FQDN of the web VM."
  value       = azurerm_public_ip.pip.fqdn
}

output "web_public_ip" {
  description = "Public IP address of the web VM."
  value       = azurerm_public_ip.pip.ip_address
}

