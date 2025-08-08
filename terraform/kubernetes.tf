# Create namespace
resource "kubernetes_namespace" "geth" {
  metadata {
    name = "geth"
  }
}

# Storage Class for high-performance storage
resource "kubernetes_storage_class" "geth_storage" {
  metadata {
    name = "geth-storage"
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  reclaim_policy      = "Retain"
  parameters = {
    type = "pd-ssd"
  }
}

# Persistent Volume for Geth data
resource "kubernetes_persistent_volume" "geth_pv" {
  metadata {
    name = "geth-pv"
    labels = {
      type = "geth-storage"
    }
  }
  spec {
    capacity = {
      storage = "${var.storage_size_gb}Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class.geth_storage.metadata[0].name
    persistent_volume_source {
      gce_persistent_disk {
        pd_name = google_compute_disk.geth_storage.name
        fs_type = "ext4"
      }
    }
  }
}

# Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "geth_pvc" {
  metadata {
    name      = "geth-pvc"
    namespace = kubernetes_namespace.geth.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.storage_size_gb}Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.geth_pv.metadata[0].name
  }
}