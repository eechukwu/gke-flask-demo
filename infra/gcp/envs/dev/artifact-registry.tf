resource "google_artifact_registry_repository" "flask_repo" {
  location      = var.region
  repository_id = "flask-repo"
  format        = "DOCKER"
  description   = "Flask demo repo for GKE"

  labels = {
    environment = var.environment
  }
}