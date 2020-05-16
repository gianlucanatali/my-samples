provider "azurerm" {
  version         = "=2.0.0"
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  features {}
}

provider "random" {
  version = "~> 2.2"
}

module "workshop-core" {
  source                    = "../../../resources/terraform-modules//azure-ws-core"
  name                      = var.name
  participant_count         = 1
  participant_password      = var.vm_password
  location                  = var.azure_location
  vm_type                   = var.vm_type
  ccloud_bootstrap_servers  = var.ccloud_bootstrap_servers
  ccloud_api_key            = var.ccloud_api_key
  ccloud_api_secret         = var.ccloud_api_secret
  ccloud_topics             = var.ccloud_topics
  ccloud_sr_endpoint        = var.ccloud_sr_endpoint
  ccloud_sr_api_key         = var.ccloud_sr_api_key
  ccloud_sr_api_secret      = var.ccloud_sr_api_secret
  feedback_form_url         = ""
  bootstrap_docker_template_path  = var.bootstrap_docker_template_path
  bootstrap_vm_template_path      = var.bootstrap_vm_template_path
  docker_folder_path             = var.docker_folder_path
}