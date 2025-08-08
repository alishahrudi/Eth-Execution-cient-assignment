# Backup CronJob
resource "kubernetes_cron_job" "geth_backup" {
  metadata {
    name      = "geth-backup"
    namespace = kubernetes_namespace.geth.metadata[0].name
  }
  spec {
    schedule = "0 2 * * *"  # Daily at 2 AM
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            container {
              name  = "backup"
              image = "google/cloud-sdk:alpine"
              command = ["/bin/sh", "-c"]
              args = [
                "tar -czf - -C /geth/data . | gsutil cp - gs://${var.backup_bucket_name}/geth-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
              ]
              volume_mount {
                name       = "geth-data"
                mount_path = "/geth/data"
              }
              env {
                name = "GOOGLE_APPLICATION_CREDENTIALS"
                value = "/var/secrets/google/key.json"
              }
              volume_mount {
                name       = "google-cloud-key"
                mount_path = "/var/secrets/google"
              }
            }
            restart_policy = "OnFailure"
            volume {
              name = "geth-data"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.geth_pvc.metadata[0].name
              }
            }
            volume {
              name = "google-cloud-key"
              secret {
                secret_name = "geth-backup-key"
              }
            }
          }
        }
      }
    }
  }
}