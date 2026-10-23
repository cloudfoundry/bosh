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
  default = "10.0.11.0/24"
}

variable "second_internal_cidr" {
  default = "10.0.22.0/24"
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

variable "ci_worker_egress_cidrs" {
  type        = list(string)
  description = "Explicit CI worker egress CIDRs allowed to reach the test director."
  validation {
    condition = length(var.ci_worker_egress_cidrs) > 0 && alltrue([
      for cidr in var.ci_worker_egress_cidrs : can(cidrhost(cidr, 0)) && try(tonumber(split("/", cidr)[1]) > 0, false)
    ])
    error_message = "Specify at least one valid CI worker CIDR; zero-prefix ranges are not allowed."
  }
}
