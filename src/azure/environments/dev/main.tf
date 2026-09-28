resource "time_static" "init_date" {}

locals {
  common_tags = {
    cost_center = "lxv"
    environment = "dev"
    owner       = "lxv"
    project     = "capstone"
    created_date = coalesce(
      formatdate("YYYY-MM-DD", time_static.init_date.rfc3339)
    )
    region = replace(var.azure_region, " ", "-")
  }
}

# Capstone Resource Group
resource "azurerm_resource_group" "capstone_rg" {
  name     = var.resource_group_name
  location = var.azure_region

  tags = local.common_tags
}

