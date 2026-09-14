output "vpc_name" {
  value = module.network.network_name
}

output "subnet_name" {
  value = module.network.subnet_name
}

output "vm_names" {
  value = module.vms.vm_names
}

output "vm_public_ips" {
  value = module.vms.vm_public_ips
}

output "secret_names" {
  value = module.secrets.secret_names
}

output "service_account_email" {
  value = module.vm_service_account.email
}
