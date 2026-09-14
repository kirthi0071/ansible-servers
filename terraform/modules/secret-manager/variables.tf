variable "project_id" {
  type = string
}

variable "secret_names" {
  type = list(string)
}

variable "github_actions_service_account" {
  type = string
}
