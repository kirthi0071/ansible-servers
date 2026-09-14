resource "google_service_account" "this" {
  account_id   = var.account_id
  display_name = var.display_name
  project      = var.project_id
}

# VM logging/monitoring roles are intentionally omitted here.
# The deployer SA in this project does not have permission to mutate
# the project-level IAM policy, and the VM can operate without these
# optional writer bindings.

resource "google_service_account_iam_member" "github_actions_user" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.github_actions_service_account}"
}
