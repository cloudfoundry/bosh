resource "google_sql_database_instance" "postgres-master" {
  database_version = "POSTGRES_15"
  region           = "us-central1"
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

resource "google_sql_database" "postgres" {
  instance = google_sql_database_instance.postgres-master.name
  name     = var.database_name
}

resource "google_sql_user" "postgres_user" {
  instance = google_sql_database_instance.postgres-master.name
  name     = var.database_username
  password = var.database_password
}

resource "google_sql_ssl_cert" "postgres_client_cert" {
  common_name = "brats-ssl"
  instance    = google_sql_database_instance.postgres-master.name
}

output "gcp_postgres_endpoint" {
  value = google_sql_database_instance.postgres-master.first_ip_address
}

output "gcp_postgres_instance_name" {
  value = google_sql_database_instance.postgres-master.name
}

output "gcp_postgres_ca" {
  value = google_sql_database_instance.postgres-master.server_ca_cert.0.cert
  sensitive = true
}

output "gcp_postgres_client_cert" {
  value = google_sql_ssl_cert.postgres_client_cert.cert
  sensitive = true
}

output "gcp_postgres_client_key" {
  value = google_sql_ssl_cert.postgres_client_cert.private_key
  sensitive = true
}
