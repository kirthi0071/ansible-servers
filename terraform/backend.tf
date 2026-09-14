terraform {
  backend "gcs" {
    bucket = "terraform-gcs-ansible"
    prefix = "ansible-servers"
  }
}
