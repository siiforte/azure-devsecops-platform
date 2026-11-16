variable "name" {
  description = "Key Vault name. Globally unique, 3–24 chars, alphanumeric and hyphens only."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy the vault into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku_name" {
  description = "Key Vault SKU."
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Days to retain soft-deleted vault and secrets. Min 7, max 90."
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Prevents hard deletion during retention period. Disable for lab environments."
  type        = bool
  default     = false
}

variable "admin_ip_addresses" {
  description = "IP addresses or CIDR ranges allowed through the vault firewall."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

