locals {
  nsg_rules_flat = merge([
    for subnet_name, subnet in var.subnets : {
      for rule in subnet.nsg_rules :
      "${subnet_name}-${rule.name}" => merge(rule, {
        nsg_name = subnet_name
      })
    }
  ]...)
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-01-${var.workload}-${var.environment}-${var.azure_region}"
  location            = var.azure_region
  resource_group_name = var.resource_group_name
  address_space       = var.address_space

  tags = var.tags
}

resource "azurerm_subnet" "subnet" {
  for_each             = var.subnets
  name                 = each.key
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = var.resource_group_name
  address_prefixes     = each.value.address_prefix
}

resource "azurerm_network_security_group" "sg" {
  for_each            = var.subnets
  name                = "sg-01-${var.workload}-${each.key}-${var.environment}-${var.azure_region}"
  location            = var.azure_region
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_rule" "rules" {
  for_each = local.nsg_rules_flat

  name              = each.value.name
  priority          = each.value.priority
  direction         = each.value.direction
  access            = each.value.access
  protocol          = each.value.protocol
  source_port_range = each.value.source_port_range
  destination_port_range = each.value.destination_port_range != null ? each.value.destination_port_range : (
    length(each.value.destination_port_ranges) == 1 && each.value.destination_port_ranges[0] == "*" ? "*" : null
  )
  destination_port_ranges = each.value.destination_port_range != null ? null : (
    length(each.value.destination_port_ranges) == 1 && each.value.destination_port_ranges[0] == "*" ? null : each.value.destination_port_ranges
  )
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.sg[each.value.nsg_name].name
}

resource "azurerm_subnet_network_security_group_association" "association" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.sg[each.key].id

  depends_on = [azurerm_network_security_rule.rules]
}
