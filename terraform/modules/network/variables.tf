variable "network_name" {
  type = string
}
variable "subnet_name" {
  type = string
}
variable "region" {
  type = string
}
variable "subnet_cidr" {
  type = string
}
variable "admin_ssh_ranges" {
  type = list(string)
}
