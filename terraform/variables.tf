variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "geth-cluster"
}

variable "node_pool_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "n1-standard-8"
}

variable "storage_size_gb" {
  description = "Storage size in GB (5TB = 5120 GB)"
  type        = number
  default     = 5120
}

variable "backup_bucket_name" {
  description = "Cloud Storage bucket name for backups"
  type        = string
}

variable "geth_chart_path" {
  description = "Path to local geth-node Helm chart"
  type        = string
  default     = "../charts/geth-node"
}

variable "prometheus_chart_path" {
  description = "Path to local kube-prometheus-stack Helm chart"
  type        = string
  default     = "../charts/kube-prometheus-stack"
}