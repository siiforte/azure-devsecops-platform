# Main storage account for lxv-capstone dso engineering roadmap
resource "azurerm_storage_account" "capstone_st" {
  name                     = "lxvcapstonetf01"
  resource_group_name      = azurerm_resource_group.capstone_rg.name
  location                 = azurerm_resource_group.capstone_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
    # Protect against accidental deletion of blobs
    # Optional: Microsoft also recommends enabling blob soft delete for complete data protection
    delete_retention_policy {
      days = 7
    }
    # Protect against accidental deletion of containers
    container_delete_retention_policy {
      days = 7 # Specify data retention between 1 and 365 days
    }
  }

  tags = local.common_tags
}

resource "azurerm_management_lock" "capstone_st_lock" {
  name       = "lk-01-capstone-st01-bootstrap-eus"
  scope      = azurerm_storage_account.capstone_st.id
  lock_level = "CanNotDelete"
  notes      = "Locked in order to prevent accidental deletion of terraform state files"
}

resource "azurerm_storage_container" "capstone_sc" {
  name                  = "sc-01-tf-state-bootstrap-eus"
  storage_account_id    = azurerm_storage_account.capstone_st.id
  container_access_type = "private"
}

