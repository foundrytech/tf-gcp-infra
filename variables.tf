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