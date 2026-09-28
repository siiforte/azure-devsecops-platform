module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.capstone_rg.name
  workload            = var.workload
  address_space       = var.address_space
  environment         = var.environment
  azure_region        = var.azure_region
  vnet_name           = var.vnet_name
  subnets             = var.subnets

  tags = var.tags
}
