terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  credentials = var.gcp_credentials_json
  region      = var.region
}

resource "google_compute_address" "director-public-ip" {
  name   = "${var.name}-director-ip"
  region = var.region
}

resource "google_compute_network" "network" {
  name                    = var.name
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "bosh-subnet" {
  name          = "${var.name}-bosh-subnet"
  ip_cidr_range = var.internal_cidr
  network       = google_compute_network.network.name
  region        = var.region
}

resource "google_compute_subnetwork" "bosh-second-subnet" {
  name          = "${var.name}-bosh-second-subnet"
  ip_cidr_range = var.second_internal_cidr
  network       = google_compute_network.network.name
  region        = var.region
}

resource "google_compute_firewall" "director-ingress" {
  name    = "${var.name}-director-ingress"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "6868", "25555"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["bosh-director"]
}

resource "google_compute_firewall" "local-traffic" {
  name    = "${var.name}-local-traffic"
  network = google_compute_network.network.name

  allow {
    protocol = "all"
  }

  source_tags = ["bosh-director"]
  target_tags = ["bosh-director"]
}

resource "google_compute_firewall" "bosh-internal" {
  name    = "${var.name}-bosh-internal"
  network = google_compute_network.network.name

  allow {
    protocol = "all"
  }

  source_tags = ["bosh-deployed", "test-stemcells-bats", "test-stemcells-ipv4"]
  target_tags = ["bosh-deployed", "test-stemcells-bats", "test-stemcells-ipv4"]
}
