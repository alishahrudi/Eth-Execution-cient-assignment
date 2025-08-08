resource "google_compute_disk" "geth_storage" {
  name  = "geth-storage-disk"
  type  = "pd-ssd"
  zone  = var.zone
  size  = var.storage_size_gb
  labels = {
    environment = "production"
    purpose     = "geth-storage"
  }
}

resource "google_storage_bucket" "backup_bucket" {
  name          = var.backup_bucket_name
  location      = var.region
  force_destroy = false

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.backup_key.id
  }
}