resource "google_compute_instance" "this" {
  count        = var.vm_count
  name         = format("%s-%02d", var.name_prefix, count.index + 1)
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["ansible-managed-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_self_link
    access_config {}
  }

  service_account {
    email  = var.vm_service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "${var.bootstrap_os_user}:${var.bootstrap_ssh_public_key}"
  }

  labels = {
    managed_by = "terraform"
    role       = "ansible-managed"
  }
}
