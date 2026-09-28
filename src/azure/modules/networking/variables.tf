variable "resource_group_name" {
  type        = string
  description = "The name of the resource group that contains the networking resources."
}

variable "workload" {
  type        = string
  description = "The workload for the resources."
}
variable "environment" {
  type        = string
  description = "The environment for the resources (e.g., dev, test, prod)."
}

variable "azure_region" {
  type        = string
  description = "The region of the networking resources."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to assign to the resources."
}

# Virtual Network Variables
variable "vnet_name" {
  type        = string
  description = "The name of the virtual network."
}

variable "address_space" {
  type        = list(string)
  description = "The address space that is used by the virtual network."
}

# Virtual Network Subnet Variables
variable "subnets" {
  type = map(object({
    address_prefix = list(string)
    nsg_rules = list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = string
      destination_port_range     = optional(string)
      destination_port_ranges    = optional(list(string))
      source_address_prefix      = string
      destination_address_prefix = string
    }))
  }))
  description = "A map of subnet objects with keys as subnet names with their corresponding values being the address prefixes inside the vNet."
}

