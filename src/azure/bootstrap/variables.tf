
variable "azure_region" {
  type        = string
  default     = "eastus"
  description = "The defaultAzure region where the resources will be deployed"
}

variable "azure_subscription_id" {
  type        = string
  default     = ""
  description = "The default Azure subscription ID"
  sensitive   = true

}

variable "cost_center" {
  type        = string
  default     = "lxv"
  description = "The cost center for the resources"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "The environment for the resources"
}

variable "owner" {
  type        = string
  default     = "lxv"
  description = "The owner of the resources"
}

variable "project" {
  type        = string
  default     = "capstone"
  description = "The project for the resources"
}

variable "created_date" {
  type        = string
  default     = null
  description = "The date the resources were created"
}

# Captures the date once at creation and saves it to state
resource "time_static" "init_date" {}


locals {
  # This remains frozen until the resource is destroyed/recreated
  created_date = coalesce(
    var.created_date,
    formatdate("YYYY-MM-DD", time_static.init_date.rfc3339)
  )
}

variable "resource_group_name" {
  type        = string
  default     = "rg-01-capstone-bootstrap-eus"
  description = "The name of the resource group"
}