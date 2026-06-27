resource "azurerm_role_assignment" "capstone_ra" {
  description          = "Role assignment for the Azure Access Token"
  scope                = azurerm_resource_group.capstone_rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.capstone_sp.object_id
}
