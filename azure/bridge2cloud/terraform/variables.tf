variable "name" {
  description = "The Prefix used for all resources in this example"
}

variable "vm_password" {
  description = "SSH password for the vm"
}

# VM Variables

variable "azure_tenant_id" {
  description = "Tenant ID"
}

variable "azure_subscription_id" {
  description = "Subscription ID"
}

variable "azure_client_id" {
  description = "Client ID"
}

variable "azure_client_secret" {
  description = "Client Secret"
}

variable "vm_type" {
  description = "VM Type"
}

variable "azure_location" {
  description = "Location"
}

// Confluent Cloud variables
variable "ccloud_bootstrap_servers" {
  description = "Confluent Cloud username"
}

variable "ccloud_api_key" {
  description = "Confluent Cloud password"
}

variable "ccloud_api_secret" {
  description = "Confluent Cloud Provider"
}

variable "ccloud_topics" {
  description = "Confluent Cloud topics to precreate"
}

variable "ccloud_sr_endpoint" {
  description = "Confluent Cloud Schema Registry Endpoint"
}

variable "ccloud_sr_api_key" {
  description = "Confluent Cloud Schema Registry API key"
}

variable "ccloud_sr_api_secret" {
  description = "Confluent Cloud Schema Registry API Secret"
}

variable "bootstrap_vm_template_path" { 
  description = "File path of the bootstrap_vm.tpl"
}

variable "bootstrap_docker_template_path" { 
  description = "File path of the bootstrap_docker.tpl"
}

variable "docker_folder_path" { 
  description = "Path for the docker folder to upload in the VM"
}
