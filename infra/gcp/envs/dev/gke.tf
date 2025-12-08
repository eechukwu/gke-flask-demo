# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.zone

  # We'll manage the node pool separately
  remove_default_node_pool = true
  initial_node_count       = 1

  # Basic networking (default VPC)
  network    = "default"
  subnetwork = "default"

  # Disable features not needed for dev
  deletion_protection = false
}

# Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.gke_cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_node_count

  node_config {
    machine_type = var.gke_machine_type
    disk_size_gb = var.gke_disk_size_gb
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = var.environment
    }

    tags = ["gke-node", var.environment]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}