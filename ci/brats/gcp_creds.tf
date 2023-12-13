provider "google" {
  project     = var.project_id
  credentials = var.gcp_credentials_json
  region      = var.region
}
