variable "aws_access_key_id" {
}

variable "aws_secret_access_key" {
}

provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = "us-west-1"

  default_tags {
    tags = {
      Name     = var.env_name
      pipeline = var.pipeline
      job      = var.job
    }
  }
}
