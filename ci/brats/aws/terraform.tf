variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}

provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region     = "us-west-1"
}

variable "rds_mysql_username" {}
variable "rds_mysql_password" {}
variable "rds_mysql_databasename" {}

resource "aws_db_instance" "mysql" {
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  skip_final_snapshot  = true
  name                 = "${var.rds_mysql_databasename}"
  username             = "${var.rds_mysql_username}"
  password             = "${var.rds_mysql_password}"
  parameter_group_name = "default.mysql5.7"
}

output "aws_mysql_endpoint" {
  value = "${aws_db_instance.mysql.endpoint}"
}

variable "rds_postgres_username" {}
variable "rds_postgres_password" {}
variable "rds_postgres_databasename" {}

resource "aws_db_instance" "postgres" {
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "9.6.8"
  instance_class       = "db.t2.micro"
  skip_final_snapshot  = true
  name                 = "${var.rds_postgres_databasename}"
  username             = "${var.rds_postgres_username}"
  password             = "${var.rds_postgres_password}"
  parameter_group_name = "default.postgres9.6"
}

output "aws_postgres_endpoint" {
  value = "${aws_db_instance.postgres.endpoint}"
}
