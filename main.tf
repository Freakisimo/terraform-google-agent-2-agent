# Enable required GCP APIs
resource "google_project_service" "required_services" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com"
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# Artifact Registry Repository for A2A Agent Docker Images
resource "google_artifact_registry_repository" "a2a_repo" {
  count = var.enable_artifact_registry ? 1 : 0

  project       = var.project_id
  location      = var.region
  repository_id = "${var.prefix}-${var.artifact_registry_name}"
  description   = "Docker repository for Agent-to-Agent (A2A) protocol container images"
  format        = "DOCKER"

  labels = var.labels

  depends_on = [google_project_service.required_services]
}
