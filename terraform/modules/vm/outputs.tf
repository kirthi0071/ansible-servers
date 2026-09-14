output "vm_names" {
  value = google_compute_instance.this[*].name
}

output "vm_public_ips" {
  value = google_compute_instance.this[*].network_interface[0].access_config[0].nat_ip
}
