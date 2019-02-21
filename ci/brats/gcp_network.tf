variable "gcp_private_network_name" {}

resource "google_compute_network" "private_network" {
	name       = "${replace(var.gcp_private_network_name,".", "-")}"
	auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "network-with-private-secondary-ip-ranges" {
  name          = "${google_compute_network.private_network.name}-subnet"
  network       = "${google_compute_network.private_network.self_link}"
}

resource "google_compute_global_address" "private_ip_address" {
	provider      = "google-beta.workaround"

	project       = "cf-bosh-core"
	name          = "${google_compute_network.private_network.name}-db-private-ip"
	purpose       = "VPC_PEERING"
	address_type  = "INTERNAL"
	prefix_length = 16
	network       = "${google_compute_network.private_network.self_link}"
}

resource "google_service_networking_connection" "private_vpc_connection" {
	provider      = "google-beta.workaround"
	network       = "${google_compute_network.private_network.self_link}"
	service       = "servicenetworking.googleapis.com"
	reserved_peering_ranges = ["${google_compute_global_address.private_ip_address.name}"]
}
