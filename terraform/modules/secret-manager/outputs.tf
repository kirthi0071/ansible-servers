output "secret_names" {
  value = [for s in google_secret_manager_secret.user_password : s.secret_id]
}
