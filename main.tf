resource "google_compute_network" "vpc_network" {
  name         = var.vpc_name
  project      = var.project_id
  routing_mode = var.routing_mode

  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.subnet_name1
  ip_cidr_range = var.ip_cidr_range1
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "db_subnet" {
  name                     = var.subnet_name2
  ip_cidr_range            = var.ip_cidr_range2
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true
}

# [START compute_internal_ip_private_access]
resource "google_compute_global_address" "default" {
  name         = "global-psconnect-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc_network.id
  address      = "10.3.0.5"
}
# [END compute_internal_ip_private_access]

# [START compute_forwarding_rule_private_access]
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "global-forwarding-rule"
  target                = "all-apis"
  network               = google_compute_network.vpc_network.id
  ip_address            = google_compute_global_address.default.id
  load_balancing_scheme = ""
}
# [END compute_forwarding_rule_private_access]

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

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.instance_tag]
}

resource "google_compute_firewall" "restrict-ssh" {
  name    = "restrict-ssh"
  network = google_compute_network.vpc_network.name

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.instance_tag]
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
