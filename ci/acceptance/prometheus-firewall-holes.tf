resource "google_compute_firewall" "internal-to-director-prometheus" {
  name    = "${var.env_id}-internal-to-director-prometheus"
  network = "${google_compute_network.bbl-network.name}"

  source_tags = ["${var.env_id}-internal"]

  allow {
    ports    = ["9091"]
    protocol = "tcp"
  }

  target_tags = ["${var.env_id}-bosh-director"]
}

resource "google_compute_firewall" "prometheus-external" {
  name    = "${var.env_id}-prometheus-external"
  network = "${google_compute_network.bbl-network.name}"

  source_ranges = ["0.0.0.0/0"]

  allow {
    ports    = ["22", "80", "3000", "9090", "9093"]
    protocol = "tcp"
  }

  target_tags = ["${var.env_id}-prometheus-nginx"]
}
