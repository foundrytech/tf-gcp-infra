variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "routing_mode" {
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

variable "app_firewall_name" {
  type = string
}

variable "protocol" {
  type = string
}

variable "app_port" {
  type = string
}

variable "app_source_range" {
  type = string
}

variable "app_tag" {
  type = string
}

variable "ssh_firewall_name" {
  type = string
}

variable "ssh_port" {
  type = string
}

variable "ssh_source_range" {
  type = string
}

# [START vpc_postgres_instance_private_ip_address]
variable "psc_ip_name" {
  type = string
}

variable "psc_purpose" {
  type = string
}

variable "psc_ip_address_type" {
  type = string
}

variable "psc_ip_prefix_length" {
  type = number
}

variable "psc_forwarding_rule_name" {
  type = string
}
# [END vpc_postgres_instance_private_ip_address]

variable "psc_connection_service" {
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

// [START setup db and db user]
variable "db_name" {
  type = string
}

variable "db_password_length" {
  type = number
}

variable "db_user" {
  type = string
}

variable "db_port" {
  type = number
}
// [END setup db and db user]


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

variable "allow_stopping_for_update" {
  type = bool
}

variable "disk_type" {
  type = string
}

variable "disk_size" {
  type = number
}

variable "app_external_ip_name" {
  type = string
}

variable "service_account_id" {
  type = string
}

variable "service_account_name" {
  type = string
}

variable "service_account_role1" {
  type = string
}

variable "service_account_role2" {
  type = string
}

variable "service_account_scopes" {
  type = list(string)
}
// [End setup Compute Engine instance]

// [START setup Cloud DNS]
variable "dns_zone_name" {
  type = string
}

variable "dns_type" {
  type = string
}

variable "a_record_ttl" {
  type = number
}
// [END setup Cloud DNS]
