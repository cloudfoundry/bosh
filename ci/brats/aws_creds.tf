variable "aws_access_key_id" {
}

variable "aws_secret_access_key" {
}

variable "aws_role_arn" {
}

provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = "us-west-1"

  assume_role {
    role_arn     = var.aws_role_arn
  }
}
