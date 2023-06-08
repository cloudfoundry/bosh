variable "rds_postgres_username" {
}

variable "rds_postgres_password" {
}

variable "rds_postgres_databasename" {
}

resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "15.3"
  instance_class         = "db.t4g.micro"
  skip_final_snapshot    = true
  db_name                = var.rds_postgres_databasename
  username               = var.rds_postgres_username
  password               = var.rds_postgres_password
  vpc_security_group_ids = [aws_security_group.allow-db-access.id]
  db_subnet_group_name   = aws_db_subnet_group.default.id
  parameter_group_name   = "postgres15"
  publicly_accessible    = true
}

output "aws_postgres_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

