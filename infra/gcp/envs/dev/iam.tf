# Service Account for GitHub Actions
resource "google_service_account" "gh_actions" {
  account_id   = "gh-actions-deployer"
  display_name = "GitHub Actions Deployer"
}

# Container Admin role
resource "google_project_iam_member" "gh_actions_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.gh_actions.email}"
}

# Artifact Registry Writer role
resource "google_project_iam_member" "gh_actions_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.gh_actions.email}"
}