resource "google_compute_network" "vpc_network" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  project                         = var.project_id
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.subnet_name1
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

resource "google_compute_firewall" "allow-app" {
  name    = "allow-app-traffic"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_tags = ["webapp"]
}

resource "google_compute_firewall" "restrict-ssh" {
  name    = "restrict-ssh"
  network = google_compute_network.vpc_network.name

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

data "google_compute_image" "custom_image" {
  family = var.image_family
}

resource "google_compute_address" "external_ip" {
  name = "external-ip-address"
}

resource "google_compute_instance" "webapp_instance" {
  name         = var.instance_name
  tags         = [var.instance_tag]
  zone         = var.zone
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = data.google_compute_image.custom_image.self_link
      type  = var.disk_type
      size  = var.disk_size
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.webapp_subnet.name
    access_config {
      nat_ip = google_compute_address.external_ip.address
    }
  }
}
