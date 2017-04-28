variable "ssh_public_key" {}

variable "access_key" {}

variable "secret_key" {}

variable "region" {}

variable "env_name" {}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name = "${var.env_name}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_route_table" "default" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id = "${aws_subnet.default.id}"
  route_table_id = "${aws_route_table.default.id}"
}

resource "aws_subnet" "default" {
  vpc_id = "${aws_vpc.default.id}"
  cidr_block = "${aws_vpc.default.cidr_block}"
  depends_on = ["aws_internet_gateway.default"]
  availability_zone = "us-east-1a"

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_network_acl" "allow_all" {
  vpc_id = "${aws_vpc.default.id}"
  subnet_ids = ["${aws_subnet.default.id}"]
  egress {
    protocol = "-1"
    rule_no = 2
    action = "allow"
    cidr_block =  "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  ingress {
    protocol = "-1"
    rule_no = 1
    action = "allow"
    cidr_block =  "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  tags {
      Name = "${var.env_name}"
  }
}

resource "aws_security_group" "allow_all" {
  vpc_id = "${aws_vpc.default.id}"
  name = "allow_all-${var.env_name}"
  description = "Allow all inbound and outgoing traffic"

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_eip" "director" {
  vpc = true
}

resource "aws_eip" "deployment" {
  vpc = true
}

# Create a new load balancer
resource "aws_elb" "default" {
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  subnets = ["${aws_subnet.default.id}"]

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_vpc_endpoint" "private-s3" {
    vpc_id = "${aws_vpc.default.id}"
    service_name = "com.amazonaws.${var.region}.s3"
    route_table_ids = ["${aws_route_table.default.id}"]
}

resource "aws_s3_bucket" "blobstore" {
  bucket = "cpi-pipeline-blobstore-${var.env_name}"
  force_destroy = true
}

resource "aws_key_pair" "main" {
  key_name   = "${var.env_name}"
  public_key = "${var.ssh_public_key}"
}

output "KeyPairPublic" {
    value = "${aws_key_pair.main.public_key}"
}

output "KeyPairName" {
    value = "${aws_key_pair.main.key_name}"
}

output "VPCID" {
  value = "${aws_vpc.default.id}"
}

output "SecurityGroupID" {
  value = "${aws_security_group.allow_all.id}"
}

output "DirectorEIP" {
  value = "${aws_eip.director.public_ip}"
}

output "DeploymentEIP" {
  value = "${aws_eip.deployment.public_ip}"
}

output "DirectorStaticIP" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 6)}"
}

output "AvailabilityZone" {
  value = "${aws_subnet.default.availability_zone}"
}

output "PublicSubnetID" {
  value = "${aws_subnet.default.id}"
}

output "PublicCIDR" {
  value = "${aws_vpc.default.cidr_block}"
}

output "PublicGateway" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 1)}"
}

output "DNS" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 2)}"
}

output "ReservedRange" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 2)}-${cidrhost(aws_vpc.default.cidr_block, 9)}"
}

output "StaticRange" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 10)}-${cidrhost(aws_vpc.default.cidr_block, 30)}"
}

output "StaticIP1" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 29)}"
}

output "StaticIP2" {
  value = "${cidrhost(aws_vpc.default.cidr_block, 30)}"
}

output "ELB" {
  value = "${aws_elb.default.id}"
}

output "ELBEndpoint" {
  value = "${aws_elb.default.dns_name}"
}

output "BlobstoreBucket" {
  value = "${aws_s3_bucket.blobstore.id}"
}
