variable "project_id" {
  type = string
}

variable "gcp_credentials_json" {
  type = string
}

variable "region" {
  default = "europe-west2"
}

variable "concourse_authorized_network" {
  default = "0.0.0.0/0"
}

variable "database_name" {
  type = string
}

variable "database_username" {
  type = string
}

variable "database_password" {
  type = string
}
