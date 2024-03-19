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
  name    = var.app_firewall_name
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = var.protocol
    ports    = [var.app_port]
  }

  source_ranges = [var.app_source_range]
  target_tags   = [var.app_tag]
}

resource "google_compute_firewall" "restrict-ssh" {
  name    = var.ssh_firewall_name
  network = google_compute_network.vpc_network.self_link

  deny {
    protocol = var.protocol
    ports    = [var.ssh_port]
  }
  source_ranges = [var.ssh_source_range]
}

# [START vpc_postgres_instance_private_ip_address]
resource "google_compute_global_address" "psc_ip_address" {
  name          = var.psc_ip_name
  purpose       = var.psc_purpose
  address_type  = var.psc_ip_address_type
  prefix_length = var.psc_ip_prefix_length
  network       = google_compute_network.vpc_network.self_link
}
# [END vpc_postgres_instance_private_ip_address]

# [START vpc_postgres_instance_private_ip_service_connection]
resource "google_service_networking_connection" "psc_connection" {
  network                 = google_compute_network.vpc_network.self_link
  service                 = var.psc_connection_service
  reserved_peering_ranges = [google_compute_global_address.psc_ip_address.name]
}
# [END vpc_postgres_instance_private_ip_service_connection]

// [START setup Cloud SQL instance and enable PSC]
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "db_instance" {
  name                = "private-ip-db-instance-${random_id.db_name_suffix.hex}"
  database_version    = var.db_version
  deletion_protection = false

  depends_on = [google_service_networking_connection.psc_connection]

  settings {
    edition           = var.db_edition
    availability_type = var.db_availability_type
    tier              = var.db_tier
    disk_type         = var.db_disk_type
    disk_size         = var.db_disk_size

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc_network.self_link
    }
  }
}
# [END setup Cloud SQL instance]

# [START create db in Cloud SQL instance]
resource "google_sql_database" "db" {
  name     = var.db_name
  instance = google_sql_database_instance.db_instance.name
}
# [END create db in Cloud SQL instance]

# [START setup db user and password]
resource "random_password" "db_password" {
  length  = var.db_password_length
  special = true
}

resource "google_sql_user" "db_user" {
  name     = var.db_user
  instance = google_sql_database_instance.db_instance.name
  password = random_password.db_password.result
}
// [END setup db user and password]

# [START setup app instance]
data "google_compute_image" "custom_image" {
  family = var.image_family
}

resource "google_compute_address" "external_ip" {
  name = var.app_external_ip_name
}

resource "google_compute_instance" "app_instance" {
  name         = var.app_instance_name
  tags         = [var.app_tag]
  machine_type = var.machine_type
  allow_stopping_for_update = var.allow_stopping_for_update

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
  metadata = {
    startup-script = <<-EOT

    #!/bin/bash
    set -e

    FLAG="APPENDED"
    ENV_FILE="/opt/myapp/app.properties"

    if ! grep -q "$FLAG" "$ENV_FILE"; then
      {
        echo "DB_NAME=${var.db_name}";
        echo "DB_USER=${var.db_user}";
        echo "DB_PORT=${var.db_port}";
        echo "DB_PASSWORD=${random_password.db_password.result}";
        echo "DB_HOST=${google_sql_database_instance.db_instance.private_ip_address}";
        
        echo "$FLAG"
      } | sudo tee -a "$ENV_FILE" > /dev/null
      
    fi

    cat "$ENV_FILE"
    EOT
  }
}
# [END setup app instance]

# [START setup DNS zone and record set]

// we use data instead of resource to interact with existing DNS zone created in GCP console 
data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone_name
}

resource "google_dns_record_set" "app_dns" {
  name         = data.google_dns_managed_zone.dns_zone.dns_name
  type         = var.dns_type
  ttl          = var.a_record_ttl
  managed_zone = data.google_dns_managed_zone.dns_zone.name
  rrdatas      = [google_compute_instance.app_instance.network_interface[0].access_config[0].nat_ip]
}
# [END setup DNS zone and record set]