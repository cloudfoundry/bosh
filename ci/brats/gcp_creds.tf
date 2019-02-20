provider "google" {
  # export GOOGLE_CREDENTIALS as env var
  project     = "cf-bosh-core"
  region      = "us-central1"
}

provider "google-beta" {
  version     = "~> 1.20"

  alias = "workaround"
}
