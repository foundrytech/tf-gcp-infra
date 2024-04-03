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

output "lb_ip" {
  description = "Public IP address of the load balancer."
  value       = google_compute_global_address.lb_ip.address
}

output "psc_ip_address" {
  description = "The private IP address of the postgres instance."
  value       = google_sql_database_instance.db_instance.private_ip_address
}
