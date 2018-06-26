variable "gcp_postgres_username" {}
variable "gcp_postgres_password" {}
variable "gcp_postgres_databasename" {}

resource "google_sql_database_instance" "master" {
  name             = "master-instance"
  database_version = "POSTGRES_9_6"
  region           = "us-central1"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "postgres" {
  instance  = "${google_sql_database_instance.master.name}"
  name      = "${var.gcp_postgres_databasename}"
  charset   = "latin1"
  collation = "latin1_swedish_ci"
}

resource "google_sql_user" "users" {
  instance = "${google_sql_database_instance.master.name}"
  name     = "${var.gcp_postgres_username}"
  password = "${var.gcp_postgres_password}"
}
