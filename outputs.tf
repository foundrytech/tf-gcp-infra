output "vpc_id" {
  value = google_compute_network.vpc_network.id
}

output "project_id" {
  description = "The project id used when managing resources."
  value       = var.project_id
}

output "region" {
  description = "The region used when managing resources."
  value       = var.region
}

output "nat_ip" {
  description = "Public IP address of the example compute instance."
  value       = google_compute_instance.app_instance.network_interface[0].access_config[0].nat_ip
}