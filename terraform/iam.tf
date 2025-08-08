resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
}

resource "google_project_iam_member" "node_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# KMS for backup encryption
resource "google_kms_key_ring" "backup_key_ring" {
  name     = "geth-backup-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "backup_key" {
  name     = "geth-backup-key"
  key_ring = google_kms_key_ring.backup_key_ring.id
}