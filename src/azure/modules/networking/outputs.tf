output "subnet_ids" {
  description = "A map of subnet names to subnet IDs."
  value = {
    for key, subnet in azurerm_subnet.subnet : key => subnet.id
  }
}

output "nsg_ids" {
  description = "A map of NSG names to NSG IDs."
  value = {
    for key, nsg in azurerm_network_security_group.sg : key => nsg.id
  }
}