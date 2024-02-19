resource "google_compute_network" "vpc_network" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  project                         = var.project_id
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  
  ip_cidr_range = var.ip_cidr_range1
  region        = var.region
  network       = google_compute_network.vpc_network.name
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = var.subnet_name2
  ip_cidr_range = var.ip_cidr_range2
  region        = var.region
  network       = google_compute_network.vpc_network.name
}

# Add a route to 0.0.0.0/0 for the vpc network
resource "google_compute_route" "vpc_route" {
  name             = var.route_name
  dest_range       = var.route_dest_range
  network          = google_compute_network.vpc_network.name
  next_hop_gateway = var.next_hop_gateway
}
