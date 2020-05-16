variable "name" {
  description = "The Prefix used for all resources in this example"
}

variable "participant_count" {
  description = "How number of participants attending the workshop"
  type        = number
}

variable "participant_password" {
  description = "Password for the admin user, to log in from ssh"
}


# VM Variables
variable "vm_type" {
  description = "VM Type"
}

variable "location" {
  description = "Location"
}

# CCloud Variables
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

variable "feedback_form_url" {
  description = "Feedback Form Url"
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
