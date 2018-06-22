variable "rds_mysql_username" {}
variable "rds_mysql_password" {}
variable "rds_mysql_databasename" {}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}

provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region     = "us-west-1"
}

resource "aws_db_instance" "default" {
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

output "endpoint" {
  value = "${aws_db_instance.default.endpoint}"
}
