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

resource "google_compute_firewall" "allow-to-lb" {
  name    = var.lb_firewall_name
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = var.protocol
    ports    = [var.lb_port]
  }

  source_ranges = [var.to_lb_source_range]
}

resource "google_compute_firewall" "allow-to-app" {
  name    = var.app_firewall_name
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = var.protocol
    ports    = [var.app_port]
  }

  source_ranges = var.to_app_source_ranges
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

// [START vpc_postgres_instance_private_ip_address]
resource "google_compute_global_address" "psc_ip_address" {
  name          = var.psc_ip_name
  purpose       = var.psc_purpose
  address_type  = var.psc_ip_address_type
  prefix_length = var.psc_ip_prefix_length
  network       = google_compute_network.vpc_network.self_link
}
// [END vpc_postgres_instance_private_ip_address]

// [START vpc_postgres_instance_private_ip_service_connection]
resource "google_service_networking_connection" "psc_connection" {
  network                 = google_compute_network.vpc_network.self_link
  service                 = var.psc_connection_service
  reserved_peering_ranges = [google_compute_global_address.psc_ip_address.name]
}
// [END vpc_postgres_instance_private_ip_service_connection]

// [START setup Cloud SQL instance and enable PSC]
resource "random_id" "random_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "db_instance" {
  name                = "private-ip-db-instance-${random_id.random_suffix.hex}"
  database_version    = var.db_version
  encryption_key_name = google_kms_crypto_key.for_db.id
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
// [END setup Cloud SQL instance]

// [START create db in Cloud SQL instance]
resource "google_sql_database" "db" {
  name     = var.db_name
  instance = google_sql_database_instance.db_instance.name
}
// [END create db in Cloud SQL instance]

// [START setup db user and password]
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

// [START setup app vm instance related resources]
data "google_compute_image" "latest_packer_image" {
  family = var.image_family
}

resource "google_service_account" "for_app_instance" {
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
}

resource "google_project_iam_member" "logging_admin_iam" {
  project = var.project_id
  role    = var.role_for_logging
  member = "serviceAccount:${google_service_account.for_app_instance.email}"
}

resource "google_project_iam_member" "monitoring_metric_writer_iam" {
  project = var.project_id
  role    = var.role_for_monitoring
  member = "serviceAccount:${google_service_account.for_app_instance.email}"
}

resource "google_compute_region_instance_template" "for_webapp" {
  name_prefix  = var.instance_template_name_prefix
  region       = var.region
  machine_type = var.machine_type

  disk {
    source_image = data.google_compute_image.latest_packer_image.self_link
    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.for_webapp.id
    }
    type         = var.disk_type
    disk_size_gb = var.disk_size
  }

  service_account {
    email  = google_service_account.for_app_instance.email
    scopes = var.service_account_scopes
  }

  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.app_subnet.self_link
    access_config {}
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

resource "google_compute_health_check" "for_webapp" {
  name = var.health_check_name

  timeout_sec         = var.health_check_timeout_sec
  check_interval_sec  = var.health_check_interval_sec
  healthy_threshold   = var.health_check_healthy_threshold
  unhealthy_threshold = var.health_check_unhealthy_threshold

  http_health_check {
    port         = var.health_check_port
    request_path = var.health_check_request_path
  }

  log_config {
    enable = var.health_check_log_enabled
  }
}

resource "google_compute_region_instance_group_manager" "for_webapp" {
  name                      = "${var.instance_group_manager_name}-${random_id.random_suffix.hex}"
  base_instance_name        = var.instance_group_manager_base_instance_name
  region                    = var.region
  distribution_policy_zones = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]

  version {
    name              = var.instance_group_manager_version_name
    instance_template = google_compute_region_instance_template.for_webapp.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.for_webapp.id
    initial_delay_sec = var.auto_healing_policies_initial_delay_sec
  }

  named_port {
    name = var.instance_group_manager_named_port_name
    port = var.instance_group_manager_named_port_port
  }
}

resource "google_compute_region_autoscaler" "for_webapp" {
  name   = var.autoscaler_name
  region = var.region
  target = google_compute_region_instance_group_manager.for_webapp.id

  autoscaling_policy {
    min_replicas    = var.autoscaling_policy_min_replicas
    max_replicas    = var.autoscaling_policy_max_replicas
    cooldown_period = var.autoscaling_policy_cool_down_period_sec

    cpu_utilization {
      target = var.autoscaling_policy_cpu_utilization_target
    }
    scale_in_control {
      max_scaled_in_replicas {
        fixed = var.autoscaling_policy_scale_in_control_max_scaled_in_replicas
      }
      time_window_sec = var.autoscaling_policy_scale_in_control_time_window_sec
    }
  }
}
// [END setup app vm instance related resources]

// [START setup Load Balancer]
resource "google_service_account" "for_lb" {
  account_id   = var.lb_service_account_id
  display_name = var.lb_service_account_display_name
  project      = var.project_id
}

resource "google_project_iam_member" "security_admin" {
  project = var.project_id
  role    = var.role_for_security_admin
  member  = "serviceAccount:${google_service_account.for_lb.email}"
}

resource "google_project_iam_member" "network_admin" {
  project = var.project_id
  role    = var.role_for_network_admin
  member  = "serviceAccount:${google_service_account.for_lb.email}"
}

resource "google_compute_managed_ssl_certificate" "for_lb" {
  name = var.managed_ssl_certificate_name
  managed {
    domains = [var.managed_ssl_certificate_domain]
  }
}

resource "google_compute_global_address" "lb_ip" {
  name = var.lb_ip_name
}

resource "google_compute_global_forwarding_rule" "for_lb" {
  name       = var.lb_frontend_name
  target     = google_compute_target_https_proxy.for_lb.self_link
  ip_address = google_compute_global_address.lb_ip.address
  port_range = var.lb_frontend_port_range
}

resource "google_compute_target_https_proxy" "for_lb" {
  name    = var.lb_target_https_proxy_name
  url_map = google_compute_url_map.for_lb.self_link
  ssl_certificates = [
    google_compute_managed_ssl_certificate.for_lb.name
  ]
  depends_on = [
    google_compute_managed_ssl_certificate.for_lb
  ]
}

resource "google_compute_url_map" "for_lb" {
  name            = var.lb_name
  default_service = google_compute_backend_service.for_lb.self_link
}

resource "google_compute_backend_service" "for_lb" {
  name                            = var.lb_backend_service_name
  protocol                        = var.lb_to_backend_service_protocol
  health_checks                   = [google_compute_health_check.for_webapp.id]
  load_balancing_scheme           = var.lb_scheme
  connection_draining_timeout_sec = var.lb_connection_draining_timeout_sec

  backend {
    group = google_compute_region_instance_group_manager.for_webapp.instance_group
  }
}
// [END setup Load Balancer]

// [START setup DNS zone and record set]
# we use data instead of resource to interact with existing DNS zone created in GCP console 
data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone_name
}

resource "google_dns_record_set" "app_dns" {
  name         = data.google_dns_managed_zone.dns_zone.dns_name
  type         = var.dns_type
  ttl          = var.a_record_ttl
  managed_zone = data.google_dns_managed_zone.dns_zone.name
  rrdatas      = [google_compute_global_address.lb_ip.address]
}
// [END setup DNS zone and record set]

// [START Pub/Sub topic, subscription and IAM binding]
resource "google_pubsub_topic" "topic" {
  name = var.pubsub_topic_name

  message_retention_duration = var.message_retention_duration
}

resource "google_pubsub_topic_iam_binding" "pubsub_publisher_iam" {
  topic = google_pubsub_topic.topic.name
  role  = var.role_for_pubsub_publisher

  members = [
    "serviceAccount:${google_service_account.for_app_instance.email}",
  ]
}
//[END Pub/Sub topic and IAM binding]

// [START setup Cloud Function]
resource "google_storage_bucket" "bucket" {
  name     = "cloud-function-bucket-${random_id.random_suffix.hex}"
  location = var.bucket_location
  encryption {
    default_kms_key_name = google_kms_crypto_key.for_storage_bucket.id
  }
  depends_on = [google_kms_crypto_key_iam_member.for_storage_bucket]
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
  display_name = var.cloud_function_service_account_display_name
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
// [END setup Cloud Function]

// [START setup CMEK]
resource "google_kms_key_ring" "default" {
  name     = "key-ring-${random_id.random_suffix.hex}"
  location = var.region
}

resource "google_kms_crypto_key" "for_webapp" {
  name            = "key-for-vm-${random_id.random_suffix.hex}"
  key_ring        = google_kms_key_ring.default.id
  rotation_period = var.key_rotation_period
}

resource "google_kms_crypto_key" "for_db" {
  name            = "key-for-db-${random_id.random_suffix.hex}"
  key_ring        = google_kms_key_ring.default.id
  rotation_period = var.key_rotation_period
}

resource "google_kms_crypto_key" "for_storage_bucket" {
  name            = "key-for-storage-bucket-${random_id.random_suffix.hex}"
  key_ring        = google_kms_key_ring.default.id
  rotation_period = var.key_rotation_period
}


data "google_project" "my_project" {}
resource "google_project_iam_member" "kms_binding" {
  project = var.project_id
  role    = var.role_for_kms_crypto_key
  member = "serviceAccount:service-${data.google_project.my_project.number}@compute-system.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "for_webapp" {
  crypto_key_id = google_kms_crypto_key.for_webapp.id
  role          = var.role_for_kms_crypto_key
  member        = "serviceAccount:${google_service_account.for_app_instance.email}"
}


resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  project  = var.project_id
  service  = "sqladmin.googleapis.com"
}
resource "google_kms_crypto_key_iam_member" "for_db" {
  provider      = google-beta
  crypto_key_id = google_kms_crypto_key.for_db.id
  role          = var.role_for_kms_crypto_key
  member        = "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}"
}


data "google_storage_project_service_account" "for_gcs" {}
resource "google_kms_crypto_key_iam_member" "for_storage_bucket" {
  crypto_key_id = google_kms_crypto_key.for_storage_bucket.id
  role          = var.role_for_kms_crypto_key
  member        = "serviceAccount:${data.google_storage_project_service_account.for_gcs.email_address}"
}
// [End setup CMEK]
