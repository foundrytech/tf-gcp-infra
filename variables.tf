variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "routing_mode" {
  type = string
}

variable "app_subnet_name" {
  type = string
}

variable "app_ip_cidr_range" {
  type = string
}

variable "db_subnet_name" {
  type = string
}

variable "db_ip_cidr_range" {
  type = string
}

variable "route_name" {
  type = string
}

variable "route_dest_range" {
  type = string
}

variable "next_hop_gateway" {
  type = string
}

variable "lb_firewall_name" {
  type = string
}

variable "protocol" {
  type = string
}

variable "lb_port" {
  type = string
}

variable "to_lb_source_range" {
  type = string
}

variable "app_firewall_name" {
  type = string
}

variable "app_port" {
  type = string
}

variable "to_app_source_ranges" {
  type = list(string)
}

variable "ssh_firewall_name" {
  type = string
}

variable "ssh_port" {
  type = string
}

variable "ssh_source_range" {
  type = string
}

// [START vpc_postgres_instance_private_ip_address]
variable "psc_ip_name" {
  type = string
}

variable "psc_purpose" {
  type = string
}

variable "psc_ip_address_type" {
  type = string
}

variable "psc_ip_prefix_length" {
  type = number
}

variable "psc_forwarding_rule_name" {
  type = string
}
// [END vpc_postgres_instance_private_ip_address]

variable "psc_connection_service" {
  type = string
}

// [START Cloud SQL instance]
variable "db_version" {
  type = string
}

variable "db_edition" {
  type = string
}

variable "db_availability_type" {
  type = string
}

variable "db_tier" {
  type = string
}

variable "db_disk_type" {
  type = string
}

variable "db_disk_size" {
  type = number
}
// [END Cloud SQL instance]

// [START db and db user]
variable "db_name" {
  type = string
}

variable "db_password_length" {
  type = number
}

variable "db_user" {
  type = string
}

variable "db_port" {
  type = number
}
// [END db and db user]


// [START vm instance related variables]
variable "image_family" {
  type = string
}

variable "service_account_id" {
  type = string
}

variable "service_account_display_name" {
  type = string
}

variable "role_for_logging" {
  type = string
}

variable "role_for_monitoring" {
  type = string
}

# Instance template
variable "instance_template_name_prefix" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "disk_type" {
  type = string
}

variable "disk_size" {
  type = number
}

variable "service_account_scopes" {
  type = list(string)
}

# Health check
variable "health_check_name" {
  type = string
}

variable "health_check_timeout_sec" {
  type = number
}

variable "health_check_interval_sec" {
  type = number
}

variable "health_check_healthy_threshold" {
  type = number
}

variable "health_check_unhealthy_threshold" {
  type = number
}

variable "health_check_port" {
  type = number
}

variable "health_check_request_path" {
  type = string
}

variable "health_check_log_enabled" {
  type = bool
}
# compute region instance group manager 
variable "instance_group_manager_name" {
  type = string
}

variable "instance_group_manager_base_instance_name" {
  type = string
}

variable "instance_group_manager_version_name" {
  type = string
}

variable "auto_healing_policies_initial_delay_sec" {
  type = string
}

variable "instance_group_manager_named_port_name" {
  type = string
}

variable "instance_group_manager_named_port_port" {
  type = number
}
# region autoscaler
variable "autoscaler_name" {
  type = string
}

variable "autoscaling_policy_min_replicas" {
  type = number
}

variable "autoscaling_policy_max_replicas" {
  type = number
}

variable "autoscaling_policy_cool_down_period_sec" {
  type = number
}

variable "autoscaling_policy_cpu_utilization_target" {
  type = number
}

variable "autoscaling_policy_scale_in_control_max_scaled_in_replicas" {
  type = number
}

variable "autoscaling_policy_scale_in_control_time_window_sec" {
  type = number
}
// [End vm instance related variables]

// [START setup Load Balancer]
variable "lb_service_account_id" {
  type = string
}

variable "lb_service_account_display_name" {
  type = string
}

variable "role_for_security_admin" {
  type = string
}

variable "role_for_network_admin" {
  type = string
}

variable "managed_ssl_certificate_name" {
  type = string
}

variable "managed_ssl_certificate_domain" {
  type = string
}

variable "lb_ip_name" {
  type = string
}

variable "lb_frontend_name" {
  type = string
}

variable "lb_frontend_port_range" {
  type = string
}

variable "lb_target_https_proxy_name" {
  type = string
}

variable "lb_name" {
  type = string
}

variable "lb_backend_service_name" {
  type = string
}

variable "lb_to_backend_service_protocol" {
  type = string
}

variable "lb_scheme" {
  type = string
}

variable "lb_connection_draining_timeout_sec" {
  type = number
}


// [START Cloud DNS]
variable "dns_zone_name" {
  type = string
}

variable "dns_type" {
  type = string
}

variable "a_record_ttl" {
  type = number
}
// [END setup Cloud DNS]

// [START Pub/Sub]
variable "pubsub_topic_name" {
  type = string
}

variable "message_retention_duration" {
  type = string
}

variable "role_for_pubsub_publisher" {
  type = string
}
// [END Pub/Sub]

// [START setup Cloud Functions]
variable "bucket_location" {
  type = string
}

variable "archive_file_type" {
  type = string
}

variable "archive_file_source_dir" {
  type = string
}

variable "archive_file_output_path" {
  type = string
}

variable "cloud_function_service_account_id" {
  type = string
}

variable "cloud_function_service_account_display_name" {
  type = string
}

variable "storage_bucket_object_name" {
  type = string
}

variable "cloudfunctions2_function_name" {
  type = string
}

variable "cloudfunctions2_function_location" {
  type = string
}

variable "cloudfunctions2_function_runtime" {
  type = string
}

variable "cloudfunctions2_function_entry_point" {
  type = string
}

variable "cloudfunctions2_function_available_memory" {
  type = string
}

variable "cloudfunctions2_function_available_cpu" {
  type = string
}

variable "cloudfunctions2_function_timeout_seconds" {
  type = number
}

variable "max_instance_request_concurrency" {
  type = number
}

variable "min_instance_count" {
  type = number
}

variable "max_instance_count" {
  type = number
}

// environment_variables 
variable "domain_name" {
  type = string
}

variable "mailgun_private_api_key" {
  type = string
}

variable "sender" {
  type = string
}

variable "subject" {
  type = string
}

variable "ingress_settings" {
  type = string
}

variable "all_traffic_on_latest_revision" {
  type = bool
}

variable "event_trigger_region" {
  type = string
}

variable "event_trigger_type" {
  type = string
}

variable "event_retry_policy" {
  type = string
}

variable "role_for_pubsub_subscriber" {
  type = string
}

variable "role_for_cloud_functions_invoker" {
  type = string
}

variable "vpc_connector_name" {
  type = string
}

variable "vpc_connector_ip_cidr_range" {
  type = string
}

variable "role_for_cloudsql_client" {
  type = string
}

variable "key_rotation_period" {
  type = string
}

variable "role_for_kms_crypto_key" {
  type = string
}
