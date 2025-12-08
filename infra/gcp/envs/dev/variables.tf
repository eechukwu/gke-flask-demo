variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west2-b"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# GKE
variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "k8s-interview-cluster"
}

variable "gke_node_count" {
  description = "Number of nodes"
  type        = number
  default     = 2
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-small"
}

variable "gke_disk_size_gb" {
  description = "Disk size for GKE nodes"
  type        = number
  default     = 30
}