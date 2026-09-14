resource "google_secret_manager_secret" "user_password" {
  for_each  = toset(var.secret_names)
  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "github_actions_accessor" {
  for_each  = google_secret_manager_secret.user_password
  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.github_actions_service_account}"
}
