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
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"
  parameter_group_name = "default.postgres9.6"
  publicly_accessible    = true
}

output "aws_postgres_endpoint" {
  value = "${aws_db_instance.postgres.endpoint}"
}
