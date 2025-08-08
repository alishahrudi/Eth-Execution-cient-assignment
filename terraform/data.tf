data "google_client_config" "default" {}

data "google_compute_default_service_account" "default" {
  project = var.project_id
}