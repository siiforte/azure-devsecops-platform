resource "azurerm_public_ip" "pip" {
  name                = "pip-01-${var.workload}-${var.environment}-${var.azure_region}"
  resource_group_name = azurerm_resource_group.capstone_rg.name
  location            = azurerm_resource_group.capstone_rg.location
  allocation_method   = "Static"
  domain_name_label   = "lxv-portfolio-${var.workload}"
  sku                 = "Standard"
  tags                = local.common_tags

}

resource "azurerm_network_interface" "nic" {
  name                = "nic-01-${var.workload}-${var.environment}-${var.azure_region}"
  location            = azurerm_resource_group.capstone_rg.location
  resource_group_name = azurerm_resource_group.capstone_rg.name

  ip_configuration {
    name                          = "ipconfig-01"
    subnet_id                     = module.networking.subnet_ids["snet-app"]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

  tags = local.common_tags

}

resource "azurerm_linux_virtual_machine" "web" {
  name                            = "vm-01-${var.workload}-${var.environment}-${var.azure_region}"
  resource_group_name             = azurerm_resource_group.capstone_rg.name
  location                        = azurerm_resource_group.capstone_rg.location
  size                            = "Standard_D2als_v7"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #cloud-config
    packages:
      - nginx
    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
      - echo '<h1>lxv-portfolio</h1><p>Capstone platform — Phase 5 live.</p>' > /var/www/html/index.html
    EOF
  )

  tags = local.common_tags
}


resource "azurerm_network_security_rule" "ssh_admin" {
  name                        = "AllowSshFromAdmin"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.admin_ip_addresses
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.capstone_rg.name
  network_security_group_name = module.networking.nsg_names["snet-app"]
}