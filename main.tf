resource "google_compute_network" "vpc_network" {
  name         = var.vpc_name
  project      = var.project_id
  routing_mode = var.routing_mode

  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "app_subnet" {
  name          = var.app_subnet_name
  ip_cidr_range = var.app_ip_cidr_range
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_subnetwork" "db_subnet" {
  name                     = var.db_subnet_name
  ip_cidr_range            = var.db_ip_cidr_range
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = true
}

# [START compute_internal_ip_private_access]
resource "google_compute_global_address" "default" {
  name         = "global-psconnect-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.vpc_network.self_link
  address      = "10.3.0.5"
}
# [END compute_internal_ip_private_access]

# [START compute_forwarding_rule_private_access]
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "global-forwarding-rule"
  target                = "all-apis"
  network               = google_compute_network.vpc_network.self_link
  ip_address            = google_compute_global_address.default.self_link
  load_balancing_scheme = ""
}
# [END compute_forwarding_rule_private_access]

# Add a route to 0.0.0.0/0 for the vpc network
resource "google_compute_route" "vpc_route" {
  name             = var.route_name
  dest_range       = var.route_dest_range
  network          = google_compute_network.vpc_network.self_link
  next_hop_gateway = var.next_hop_gateway
}

resource "google_compute_firewall" "allow-app" {
  name    = "allow-app-traffic"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.app_tag]
}

resource "google_compute_firewall" "restrict-ssh" {
  name    = "restrict-ssh"
  network = google_compute_network.vpc_network.self_link

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.app_tag]
}

resource "google_sql_database_instance" "db_instance" {
  name             = "main-instance"
  database_version = "POSTGRES_15"
  region           = "us-central1"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
  }
}

data "google_compute_image" "custom_image" {
  family = var.image_family
}

resource "google_compute_address" "external_ip" {
  name = "external-ip-address"
}

resource "google_compute_instance" "app_instance" {
  name         = var.app_instance_name
  tags         = [var.app_tag]
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = data.google_compute_image.custom_image.self_link
      type  = var.disk_type
      size  = var.disk_size
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.app_subnet.self_link
    access_config {
      nat_ip = google_compute_address.external_ip.address
    }
  }
}