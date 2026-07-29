# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.78.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~>3.9.0"
    }
  }
  backend "azurerm" {
    use_azuread_auth     = true
    storage_account_name = "lxvcapstonetf01"
    container_name       = "sc-01-tf-state-bootstrap-eus"
    key                  = "terraform.tfstate"
  }
}


# Configure the Microsoft Azure Provider 
provider "azurerm" {
  features {}
}

provider "azuread" {
}

