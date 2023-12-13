resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "15.3"
  instance_class         = "db.t4g.micro"
  skip_final_snapshot    = true
  db_name                = var.database_name
  username               = var.database_username
  password               = var.database_password
  vpc_security_group_ids = [aws_security_group.allow-db-access.id]
  db_subnet_group_name   = aws_db_subnet_group.default.id
  parameter_group_name   = "postgres15"
  publicly_accessible    = true
}

output "aws_postgres_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

