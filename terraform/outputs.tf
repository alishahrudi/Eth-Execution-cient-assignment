output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  value = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
}

output "geth_service_ip" {
  value = "Will be available after deployment - check with kubectl get svc -n geth"
}

output "backup_bucket_url" {
  value = "gs://${google_storage_bucket.backup_bucket.name}"
}

output "geth_storage_disk_name" {
  value = google_compute_disk.geth_storage.name
}