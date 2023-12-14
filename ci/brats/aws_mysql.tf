resource "aws_db_instance" "mysql" {
  allocated_storage      = 10
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  skip_final_snapshot    = true
  db_name                = var.database_name
  username               = var.database_username
  password               = var.database_password
  parameter_group_name   = "default.mysql5.7"
  vpc_security_group_ids = [aws_security_group.allow-db-access.id]
  db_subnet_group_name   = aws_db_subnet_group.default.id
  publicly_accessible    = true
}

output "aws_mysql_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

