variable "vpc_name" {
  type = string
}

variable "routing_mode" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "app_subnet_name" {
  type = string
}

variable "app_ip_cidr_range" {
  type = string
}

variable "db_subnet_name" {
  type = string
}

variable "db_ip_cidr_range" {
  type = string
}

variable "route_name" {
  type = string
}

variable "route_dest_range" {
  type = string
}

variable "next_hop_gateway" {
  type = string
}

variable "app_tag" {
  type = string
}
// [START setup Cloud SQL instance]
variable "db_version" {
  type = string
}

variable "db_edition" {
  type = string
}

variable "db_availability_type" {
  type = string
}

variable "db_tier" {
  type = string
}

variable "db_disk_type" {
  type = string
}

variable "db_disk_size" {
  type = number
}
// [END setup Cloud SQL instance]

# [START cloud_sql_postgres_instance_psc_endpoint]
variable "psc_name" {
  type = string
}

variable "psc_address" {
  type = string
}

variable "psc_address_type" {
  type = string
}

variable "psc_forwarding_rule_name" {
  type = string
}
// [END cloud_sql_postgres_instance_psc_endpoint]

// [START setup db and db user]
variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_port" {
  type = number
}

// [START setup Compute Engine instance]
variable "image_family" {
  type = string
}

variable "app_instance_name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "disk_type" {
  type = string
}

variable "disk_size" {
  type = number
}