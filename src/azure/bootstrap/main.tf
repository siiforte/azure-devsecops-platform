# Capstone Resource Group
resource "azurerm_resource_group" "capstone_rg" {
  name     = var.resource_group_name
  location = var.azure_region

  tags = {
    costcenter  = var.cost_center
    createddate = local.created_date
    environment = var.environment
    owner       = var.owner
    project     = var.project
    region      = replace(var.azure_region, " ", "-")
  }

}

# Registering application identity in Azure AD for Gitlab/Terraform Pipeline
resource "azuread_application_registration" "capstone_ar" {
  display_name = "ar-01-capstone-oidc"
  description  = "OIDC identity used by GitLab pipelines to manage Capstone Platform infrastructure"
}

# Create a service principal for the application to use for authentication
resource "azuread_service_principal" "capstone_sp" {
  client_id                    = azuread_application_registration.capstone_ar.client_id
  app_role_assignment_required = false
}

# Create a federated identity credential for the application to be able to use it for authentication
resource "azuread_application_federated_identity_credential" "capstone_fic" {
  application_id = azuread_application_registration.capstone_ar.id
  display_name   = "fic-01-capstone-gitlab-master"
  description    = "Allow GitLab master branch deployments for siiforte/capstone-platform"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://gitlab.com"
  subject        = "project_path:siiforte/capstone-platform:ref_type:branch:ref:master"
}
