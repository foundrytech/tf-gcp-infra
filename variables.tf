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

variable "subnet_name1" {
  type = string
}

variable "ip_cidr_range1" {
  type = string
}


variable "subnet_name2" {
  type = string
}

variable "ip_cidr_range2" {
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

variable "network_tag" {
  type = string
}

variable "image_name" {
  type = string
}

variable "image_family" {
  type = string
}

variable "image_source_disk" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "zone" {
  type = string
}

variable "disk_type" {
  type = string
}

variable "disk_size" {
  type = number
}