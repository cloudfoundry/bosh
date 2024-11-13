output "zone" {
  value = var.zone
}

output "network" {
  value = var.name
}

output "subnetwork" {
  value = google_compute_subnetwork.bosh-subnet.name
}

output "second_subnetwork" {
  value = google_compute_subnetwork.bosh-second-subnet.name
}

output "project_id" {
  value = var.project_id
}

output "internal_cidr" {
  value = var.internal_cidr
}

output "second_internal_cidr" {
  value = var.second_internal_cidr
}

output "gateway" {
  value = cidrhost(var.internal_cidr, 1)
}

output "second_gateway" {
  value = cidrhost(var.second_internal_cidr, 1)
}

output "director_public_ip" {
  value = google_compute_address.director-public-ip.address
}

output "director_ip" {
  value = cidrhost(var.internal_cidr, 2)
}

output "static_ip_first_network" {
  value = cidrhost(var.internal_cidr, 3)
}

output "second_static_ip_first_network" {
  value = cidrhost(var.internal_cidr, 4)
}

output "static_ip_second_network" {
  value = cidrhost(var.second_internal_cidr, 2)
}

output "mysql_dns_name" {
  value = element(concat(google_sql_database_instance.mysql-db.*.dns_name, [""]), 0)
}

output "mysql_user" {
  value = element(concat(google_sql_user.mysql-bosh-user.*.name, [""]), 0)
}

output "mysql_password" {
  value = element(concat(google_sql_user.mysql-bosh-user.*.password, [""]), 0)
}
