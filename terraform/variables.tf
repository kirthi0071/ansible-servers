variable "project_id" {
  type    = string
  default = "project-c98d2dac-2409-44bd-aba"
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "zone" {
  type    = string
  default = "asia-south1-a"
}

variable "network_name" {
  type    = string
  default = "ansible-vm-vpc"
}

variable "subnet_name" {
  type    = string
  default = "ansible-vm-subnet"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "vm_count" {
  type    = number
  default = 3
}

variable "vm_name_prefix" {
  type    = string
  default = "ansible-vm"
}

variable "machine_type" {
  type    = string
  default = "e2-micro"
}

variable "boot_disk_size_gb" {
  type    = number
  default = 20
}

variable "admin_ssh_source_ranges" {
  type        = list(string)
  description = "CIDRs allowed to SSH. Replace 0.0.0.0/0 before production use."
  default     = ["0.0.0.0/0"]
}

variable "bootstrap_ssh_public_key" {
  type      = string
  sensitive = true
}

variable "bootstrap_os_user" {
  type    = string
  default = "ansible-bootstrap"
}

variable "github_actions_service_account" {
  type        = string
  description = "Service account used by GitHub Actions through the existing WIF provider."
}
