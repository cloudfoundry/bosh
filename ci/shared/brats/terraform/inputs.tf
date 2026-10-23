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
  type        = string
  description = "Explicit IPv4 egress CIDR of the CI workers connecting to test databases."
  validation {
    condition     = can(cidrnetmask(var.concourse_authorized_network)) && try(tonumber(split("/", var.concourse_authorized_network)[1]) > 0, false)
    error_message = "Specify an IPv4 worker CIDR with a nonzero prefix."
  }
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
