resource "google_compute_network" "vpc_network" {
  name         = var.vpc_name
  project      = var.project_id
  routing_mode = var.routing_mode

  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "app_subnet" {
  name                     = var.app_subnet_name
  ip_cidr_range            = var.app_ip_cidr_range
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = var.db_subnet_name
  ip_cidr_range = var.db_ip_cidr_range
  network       = google_compute_network.vpc_network.self_link
}

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

// [START setup Cloud SQL instance]
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "db_instance" {
  name                = "postgres-instance-${random_id.db_name_suffix.hex}"
  database_version    = "POSTGRES_15"
  deletion_protection = false

  settings {
    edition           = "ENTERPRISE"
    availability_type = "REGIONAL"
    tier              = "db-f1-micro"
    disk_type         = "PD_SSD"
    disk_size         = "10"

    ip_configuration {
      ipv4_enabled = false

      psc_config {
        psc_enabled = true
      }
    }
  }
}
# [END setup Cloud SQL instance]

# [START cloud_sql_postgres_instance_psc_endpoint]
resource "google_compute_address" "psc_address" {
  name         = "psc-ip-address"
  address      = "192.168.1.5"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.app_subnet.self_link
}

data "google_sql_database_instance" "db_instance" {
  name = google_sql_database_instance.db_instance.name
}

resource "google_compute_forwarding_rule" "psc_forwarding_rule" {
  name                  = "forwardingrule"
  load_balancing_scheme = ""

  ip_address = google_compute_address.psc_address.self_link
  network    = google_compute_network.vpc_network.self_link
  target     = data.google_sql_database_instance.db_instance.psc_service_attachment_link
}
// [END cloud_sql_postgres_instance_psc_endpoint]

# [START setup app instance]
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
  # metadata = {
  #   startup-script = <<-EOT
  #   #!/bin/bash
  #   set -e      
  #   sudo echo "DB_HOST=${google_sql_database_instance.db_instance.private_ip_address}" > /opt/myapp/app.properties
  #   sudo echo "DB_PASSWORD=${random_password.db_password.result}" > /opt/myapp/app.properties

  #   EOT
  # }
}
# [END setup app instance]
