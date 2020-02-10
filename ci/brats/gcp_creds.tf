provider "google" {
  # export GOOGLE_CREDENTIALS as env var
  project = "cf-bosh-core"
  region  = "us-central1"
}

variable "concourse_authorized_network" {
}
