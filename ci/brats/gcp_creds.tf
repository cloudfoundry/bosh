variable "gcp_access_key_id" {}
variable "gcp_secret_access_key" {}

provider "google" {
  # export GOOGLE_CREDENTIALS as env var
  project     = "cf-bosh-core"
  region      = "us-central1"
}
