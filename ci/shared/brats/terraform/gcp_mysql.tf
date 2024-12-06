resource "google_sql_database_instance" "mysql-master" {
  database_version    = "MYSQL_8_0"
  region              = "us-central1"
  deletion_protection = false
  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "concourse"
        value = var.concourse_authorized_network
      }
    }
  }
}

resource "google_sql_database" "mysql" {
  instance = google_sql_database_instance.mysql-master.name
  name     = var.database_name
}

resource "google_sql_user" "mysql_user" {
  instance = google_sql_database_instance.mysql-master.name
  name     = var.database_username
  password = var.database_password
}

resource "google_sql_ssl_cert" "mysql_client_cert" {
  common_name = "brats-ssl"
  instance    = google_sql_database_instance.mysql-master.name
}

output "gcp_mysql_endpoint" {
  value = google_sql_database_instance.mysql-master.first_ip_address
}

output "gcp_mysql_instance_name" {
  value = google_sql_database_instance.mysql-master.name
}

output "gcp_mysql_ca" {
  value = google_sql_database_instance.mysql-master.server_ca_cert.0.cert
  sensitive = true
}

output "gcp_mysql_client_cert" {
  value = google_sql_ssl_cert.mysql_client_cert.cert
  sensitive = true
}

output "gcp_mysql_client_key" {
  value = google_sql_ssl_cert.mysql_client_cert.private_key
  sensitive = true
}
