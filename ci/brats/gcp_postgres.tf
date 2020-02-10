variable "gcp_postgres_databasename" {
}

resource "google_sql_database_instance" "postgres-master" {
  database_version = "POSTGRES_9_6"
  region           = "us-central1"

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
      authorized_networks {
        name  = "pivotal"
        value = "209.234.137.222/32"
      }
    }
  }
}

resource "google_sql_database" "postgres" {
  instance = google_sql_database_instance.postgres-master.name
  name     = var.gcp_postgres_databasename
}

output "gcp_postgres_endpoint" {
  value = google_sql_database_instance.postgres-master.first_ip_address
}

output "gcp_postgres_instance_name" {
  value = google_sql_database_instance.postgres-master.name
}

