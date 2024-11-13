variable "project_id" {
  type = string
}

variable "gcp_credentials_json" {
  type = string
}

variable "name" {
  type = string
}

variable "internal_cidr" {
  default = "10.0.0.0/24"
}

variable "second_internal_cidr" {
  default = "10.0.1.0/24"
}

variable "zone" {
  default = "europe-west2-a"
}

variable "region" {
  default = "europe-west2"
}

variable "create_mysql_db" {
  default = false
}
