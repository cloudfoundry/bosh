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

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.network.id
  service                 = "servicenetworking.googleapis.com"
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.network.id
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

resource "google_sql_database_instance" "mysql-db" {
  count            = var.create_mysql_db ? 1 : 0
  name             = "${var.name}-mysql-db"
  database_version = "MYSQL_8_0"
  region           = var.region
  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled = false
      private_network                               = google_compute_network.network.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
}

resource "random_password" "mysql-password" {
  count            = var.create_mysql_db ? 1 : 0
  length           = 16
}

resource "google_sql_user" "mysql-bosh-user" {
  count    = var.create_mysql_db ? 1 : 0
  name     = "bosh"
  instance = google_sql_database_instance.mysql-db[0].name
  password = random_password.mysql-password[0].result
}
