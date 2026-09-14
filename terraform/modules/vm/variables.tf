variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnet_self_link" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "vm_count" {
  type = number
}

variable "name_prefix" {
  type = string
}

variable "boot_disk_size_gb" {
  type = number
}

variable "vm_service_account" {
  type = string
}

variable "bootstrap_os_user" {
  type = string
}

variable "bootstrap_ssh_public_key" {
  type      = string
  sensitive = true
}
