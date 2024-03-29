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

  allow {
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
resource "random_id" "random_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "db_instance" {
  name                = "private-ip-db-instance-${random_id.random_suffix.hex}"
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

resource "google_service_account" "account" {
  account_id   = var.service_account_id
  display_name = var.service_account_name
}

resource "google_project_iam_binding" "logging_admin_iam" {
  project = var.project_id
  role    = var.role_for_logging

  members = [
    "serviceAccount:${google_service_account.account.email}",
  ]
}

resource "google_project_iam_binding" "monitoring_metric_writer_iam" {
  project = var.project_id
  role    = var.role_for_monitoring

  members = [
    "serviceAccount:${google_service_account.account.email}",
  ]
}

resource "google_compute_instance" "app_instance" {
  name                      = var.app_instance_name
  tags                      = [var.app_tag]
  machine_type              = var.machine_type
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

  service_account {
    email  = google_service_account.account.email
    scopes = var.service_account_scopes
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

# [START Pub/Sub topic, subscription and IAM binding]
resource "google_pubsub_topic" "topic" {
  name = var.pubsub_topic_name

  message_retention_duration = var.message_retention_duration
}

resource "google_pubsub_topic_iam_binding" "pubsub_publisher_iam" {
  topic = google_pubsub_topic.topic.name
  role  = var.role_for_pubsub_publisher

  members = [
    "serviceAccount:${google_service_account.account.email}",
  ]
}
//[END Pub/Sub topic and IAM binding]

# [START setup Cloud Function]
resource "google_storage_bucket" "bucket" {
  name                        = "cloud-function-bucket-${random_id.random_suffix.hex}"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
}

data "archive_file" "function_zip" {
  type        = var.archive_file_type
  source_dir  = var.archive_file_source_dir
  output_path = var.archive_file_output_path
}

resource "google_storage_bucket_object" "object" {
  name   = var.storage_bucket_object_name
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.function_zip.output_path
}

resource "google_cloudfunctions2_function" "function" {
  name     = var.cloudfunctions2_function_name
  location = var.cloudfunctions2_function_location

  build_config {
    runtime     = var.cloudfunctions2_function_runtime
    entry_point = var.cloudfunctions2_function_entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    available_memory                 = var.cloudfunctions2_function_available_memory
    available_cpu                    = var.cloudfunctions2_function_available_cpu
    timeout_seconds                  = var.cloudfunctions2_function_timeout_seconds
    max_instance_request_concurrency = var.max_instance_request_concurrency
    min_instance_count               = var.min_instance_count
    max_instance_count               = var.max_instance_count
    environment_variables = {
      DB_HOST     = google_sql_database_instance.db_instance.private_ip_address
      DB_PORT     = var.db_port
      DB_USER     = var.db_user
      DB_PASSWORD = random_password.db_password.result
      DB_NAME     = var.db_name

      DOMAIN_NAME             = var.domain_name
      MAILGUN_PRIVATE_API_KEY = var.mailgun_private_api_key
      SENDER                  = var.sender
      SUBJECT                 = var.subject
    }
    ingress_settings               = var.ingress_settings
    all_traffic_on_latest_revision = var.all_traffic_on_latest_revision
    service_account_email          = google_service_account.for_cloud_function.email
    vpc_connector                  = "projects/${var.project_id}/locations/${var.cloudfunctions2_function_location}/connectors/${google_vpc_access_connector.connector.name}"
  }

  event_trigger {
    trigger_region = var.event_trigger_region
    event_type     = var.event_trigger_type
    pubsub_topic   = google_pubsub_topic.topic.id
    retry_policy   = var.event_retry_policy
  }
}

resource "google_service_account" "for_cloud_function" {
  account_id   = var.cloud_function_service_account_id
  display_name = var.cloud_function_service_account_name
}

resource "google_project_iam_binding" "pubsub_subscriber" {
  project = var.project_id
  role    = var.role_for_pubsub_subscriber
  members = [
    "serviceAccount:${google_service_account.for_cloud_function.email}",
  ]
}

resource "google_cloudfunctions2_function_iam_binding" "cloudfunctions-invoker" {
  project        = google_cloudfunctions2_function.function.project
  location       = google_cloudfunctions2_function.function.location
  cloud_function = google_cloudfunctions2_function.function.name
  role           = var.role_for_cloud_functions_invoker
  members        = ["serviceAccount:${google_service_account.for_cloud_function.email}"]
}

# Add a VPC connector for the Cloud Function to access the Cloud SQL instance
resource "google_vpc_access_connector" "connector" {
  name          = var.vpc_connector_name
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = var.vpc_connector_ip_cidr_range
}

# Bind the IAM role to the Cloud Function's service account for access to Cloud SQL
resource "google_project_iam_binding" "cloudsql_client" {
  project = var.project_id
  role    = var.role_for_cloudsql_client
  members = ["serviceAccount:${google_service_account.for_cloud_function.email}"]
}
# [END setup Cloud Function]
