variable "gcp_mysql_username" {}
variable "gcp_mysql_password" {}
variable "gcp_mysql_databasename" {}

resource "google_sql_database_instance" "mysql-master" {
  database_version = "MYSQL_5_7"
  region           = "us-central1"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "mysql" {
  instance  = "${google_sql_database_instance.mysql-master.name}"
  name      = "${var.gcp_mysql_databasename}"
}

resource "google_sql_user" "mysql" {
  instance = "${google_sql_database_instance.mysql-master.name}"
  name     = "${var.gcp_mysql_username}"
  password = "${var.gcp_mysql_password}"
}

output "gcp_mysql_endpoint" {
  value = "${google_sql_database_instance.mysql-master.first_ip_address}"
}

output "gcp_mysql_instance_name" {
  value = "${google_sql_database_instance.mysql-master.name}"
}
