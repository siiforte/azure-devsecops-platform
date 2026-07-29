
variable "azure_region" {
  type        = string
  default     = "eastus"
  description = "The defaultAzure region where the resources will be deployed"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-01-capstone-bootstrap-eus"
  description = "The name of the resource group"
}

variable "azure_subscription_id" {
  type        = string
  default     = ""
  description = "The default Azure subscription ID"
  sensitive   = true
}