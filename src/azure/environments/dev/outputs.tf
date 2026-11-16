output "key_vault_uri" {
  description = "Key Vault URI for secret access."
  value       = module.secrets.vault_uri
}