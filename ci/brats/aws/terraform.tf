variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}

provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region     = "us-west-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "zonea" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-west-1a"
}

resource "aws_subnet" "zoneb" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-1b"
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }
}

resource "aws_route_table_association" "publica" {
  subnet_id      = "${aws_subnet.zonea.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "publicb" {
  subnet_id      = "${aws_subnet.zoneb.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_security_group" "allow-db-access" {
  name        = "allow-all"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port     = "3306"
    to_port       = "3306"
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }

  ingress {
    from_port     = "5432"
    to_port       = "5432"
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = ["${aws_subnet.zonea.id}","${aws_subnet.zoneb.id}"]
}

variable "rds_mysql_username" {}
variable "rds_mysql_password" {}
variable "rds_mysql_databasename" {}

resource "aws_db_instance" "mysql" {
  allocated_storage      = 10
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  skip_final_snapshot    = true
  name                   = "${var.rds_mysql_databasename}"
  username               = "${var.rds_mysql_username}"
  password               = "${var.rds_mysql_password}"
  parameter_group_name   = "default.mysql5.7"
  vpc_security_group_ids = ["${aws_security_group.allow-db-access.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.default.id}"
  publicly_accessible    = true
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
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"
  parameter_group_name = "default.postgres9.6"
}

output "aws_postgres_endpoint" {
  value = "${aws_db_instance.postgres.endpoint}"
}
