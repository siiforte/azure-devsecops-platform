environment = "dev"

resource_group_name = "rg-01-capstone-dev-eus"

azure_region = "eastus"

vnet_name = "vnet-01-capstone-dev-eus"

address_space = ["10.0.0.0/16"]

subnets = {
  AzureBastionSubnet = {
    address_prefix = ["10.0.0.0/26"]

    nsg_rules = [
      {
        name                       = "allow-https-inbound"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = "Internet"
        destination_address_prefix = "*"
        description                = "Allow HTTPS access to Azure Bastion"
      },
      {
        name                       = "allow-gateway-manager-inbound"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = "GatewayManager"
        destination_address_prefix = "*"
        description                = "Allow Azure platform management traffic"
      },
      {
        name                       = "allow-bastion-host-communication"
        priority                   = 120
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = ["8080", "5701"]
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
        description                = "Allow internal Bastion host communication"
      },
      {
        name                       = "allow-azure-load-balancer-inbound"
        priority                   = 130
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = "*"
        description                = "Allow Azure Load Balancer traffic required by Bastion"
      },
      {
        name                       = "allow-ssh-rdp-outbound"
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = ["22", "3389"]
        source_address_prefix      = "*"
        destination_address_prefix = "VirtualNetwork"
        description                = "Allow Bastion SSH and RDP connections to target VMs"
      },
      {
        name                       = "allow-azure-cloud-outbound"
        priority                   = 110
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = "*"
        destination_address_prefix = "AzureCloud"
        description                = "Allow Bastion communication with Azure services"
      },
      {
        name                       = "allow-bastion-communication"
        priority                   = 120
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = ["8080", "5701"]
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
        description                = "Allow internal Bastion communication"
      },
      {
        name                       = "allow-http-outbound"
        priority                   = 130
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = ["80"]
        source_address_prefix      = "*"
        destination_address_prefix = "Internet"
        description                = "Allow required outbound HTTP communication"
      }
    ]
  }

  snet-infra = {
    address_prefix = ["10.0.1.0/24"]

    nsg_rules = [
      {
        name                       = "allow-runner-to-infra"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["22", "443", "5986"]
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "10.0.1.0/24"
        description                = "Allow GitLab runner and approved infrastructure automation"
      },
      {
        name                       = "deny-internet-to-infra"
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.1.0/24"
        description                = "Prevent direct Internet exposure of infrastructure workloads"
      }
    ]
  }

  snet-runners = {
    address_prefix = ["10.0.2.0/24"]

    nsg_rules = [
      {
        name                       = "allow-runner-internet-https"
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "Internet"
        description                = "Allow runners to communicate with GitLab and external dependencies"
      },
      {
        name                       = "allow-runner-to-infra"
        priority                   = 110
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["22", "443", "5986"]
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "10.0.1.0/24"
        description                = "Allow infrastructure automation"
      },
      {
        name                       = "allow-runner-to-app"
        priority                   = 120
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["22", "5986"]
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "10.0.3.0/24"
        description                = "Allow application automation"
      },
      {
        name                       = "allow-runner-to-data"
        priority                   = 130
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["22", "5986"]
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "10.0.4.0/24"
        description                = "Allow controlled database administration automation"
      },
      {
        name                       = "deny-internet-to-runners"
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = ["*"]
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.2.0/24"
        description                = "Prevent unsolicited Internet access to runner VMs"
      }
    ]
  }

  snet-app = {
    address_prefix = ["10.0.3.0/24"]

    nsg_rules = [
      {
        name                       = "allow-app-gateway-to-app"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["80", "443"]
        source_address_prefix      = "10.0.5.0/24"
        destination_address_prefix = "10.0.3.0/24"
        description                = "Allow Application Gateway traffic to application workloads"
      },
      {
        name                       = "allow-runner-to-app"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["22", "5986"]
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "10.0.3.0/24"
        description                = "Allow CI/CD and Ansible automation to application workloads"
      },
      {
        name                       = "deny-internet-to-app"
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = ["*"]
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.3.0/24"
        description                = "Prevent direct Internet exposure of application workloads"
      }
    ]
  }

  snet-data = {
    address_prefix = ["10.0.4.0/24"]

    nsg_rules = [
      {
        name                       = "allow-app-to-data"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["1433"]
        source_address_prefix      = "10.0.3.0/24"
        destination_address_prefix = "10.0.4.0/24"
        description                = "Allow application workloads to access SQL Server"
      },
      {
        name                       = "allow-runner-to-data"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["22", "5986"]
        source_address_prefix      = "10.0.2.0/24"
        destination_address_prefix = "10.0.4.0/24"
        description                = "Allow controlled database administration automation"
      },
      {
        name                       = "deny-internet-to-data"
        priority                   = 4000
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = ["*"]
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.4.0/24"
        description                = "Prevent direct Internet exposure of database workloads"
      }
    ]
  }

  snet-app-gateway = {
    address_prefix = ["10.0.5.0/24"]

    nsg_rules = [
      {
        name                       = "allow-app-gateway-https-inbound"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.5.0/24"
        description                = "Allow public HTTPS traffic to Application Gateway"
      },
      {
        name                       = "allow-app-gateway-http-inbound"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["80"]
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.5.0/24"
        description                = "Allow HTTP traffic for HTTP-to-HTTPS redirection"
      }
    ]
  }
}


tags = {
  cost_center = "lxv"
  environment = "dev"
  owner       = "lxv"
  project     = "capstone"
}

workload = "capstone"

