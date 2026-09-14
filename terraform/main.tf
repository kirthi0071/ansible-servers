module "network" {
  source           = "./modules/network"
  network_name     = var.network_name
  subnet_name      = var.subnet_name
  region           = var.region
  subnet_cidr      = var.subnet_cidr
  admin_ssh_ranges = var.admin_ssh_source_ranges
}

module "vm_service_account" {
  source                         = "./modules/service-account"
  project_id                     = var.project_id
  account_id                     = "ansible-vm-sa"
  display_name                   = "Ansible managed VM service account"
  github_actions_service_account = var.github_actions_service_account
}

module "secrets" {
  source                         = "./modules/secret-manager"
  project_id                     = var.project_id
  secret_names                   = ["ram-password", "vicky-password", "mahesh-password"]
  github_actions_service_account = var.github_actions_service_account
}

module "vms" {
  source                    = "./modules/vm"
  project_id                = var.project_id
  zone                      = var.zone
  subnet_self_link          = module.network.subnet_self_link
  machine_type              = var.machine_type
  vm_count                  = var.vm_count
  name_prefix               = var.vm_name_prefix
  boot_disk_size_gb         = var.boot_disk_size_gb
  vm_service_account        = module.vm_service_account.email
  bootstrap_os_user         = var.bootstrap_os_user
  bootstrap_ssh_public_key  = var.bootstrap_ssh_public_key
}
