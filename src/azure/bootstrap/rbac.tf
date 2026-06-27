locals {
  role_assignments = {
    contributor = {
      role        = "Contributor"
      scope       = azurerm_resource_group.capstone_rg.id
      description = "Role assignment for the SP Workload Contributor"
    }
    blob_contributor = {
      role        = "Storage Blob Data Contributor"
      scope       = azurerm_storage_account.capstone_st.id
      description = "Role assignment for the SP Blob Contributor"
    }
  }
}

resource "azurerm_role_assignment" "capstone" {
  for_each = local.role_assignments

  role_definition_name = each.value.role
  scope                = each.value.scope
  principal_id         = azuread_service_principal.capstone_sp.object_id
  description          = each.value.description
}
