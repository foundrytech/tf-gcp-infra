# Instructions for using terraform to create VPC with gcloud as provider:

1. Install Terraform using Homebrew

```sh
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

terraform -install-autocomplete # Install autocompletion
```

2. To use GCP as terraform provider, we need Install `gcloud SDK`
   https://cloud.google.com/sdk/docs/install
3. Before use gcloud SDK, we authenticate it with commands:

```sh
gcloud auth login
# Autenticate with you google account and store the credentials locally.

gcloud auth application-default login
# It sets up ADC(Application Default Credentials) for your local development environment.
# It enables your code to use the same credentials locally during
# development as it would when deployed to the Google Cloud environment.
```

4. Enable GCP Service APIs:

- `Compute Engine API`
- `Cloud DNS API`

5. Project setup and configuration:

- Clone the project from forked github repo, `cd tf-gcp-infra`, `touch .gitignore` populate it with the example configs: https://github.com/github/gitignore/blob/main/Terraform.gitignore

```gitignore
# additinally
.terraform.lock.hcl
```

- Terraform configuration for GCP: https://registry.terraform.io/providers/hashicorp/google/latest/docs

- Create`variables.tf`file to define variable types

```tf
variable "vpc_name" {
	type = string
}

variable "project_id" {
	type = string
}
```

- Create a `terraform.tfvars` file to store variable values

```tf
vpc_name = "my-vpc"
project_id = "your-project-id"
# project_id can be found at gcloud project.
...
```

- Create `providers.tf` to add provider info:

```tf
provider "google" {
	project = var.project_id
}
```

- Create`main.tf` add content for vpc configurations

```tf
resource "google_compute_network" "vpc_network" {
	name = var.vpc_name
	description = "My vpc network"
	auto_create_subnetworks = false
	routing_mode = "REGIONAL"
	project = var.project_id
}
```

- Add Network Firewall using Terraform : 
 Set up firewall rules for you custom VPC/Subnet to allow traffic from the internet to the port your application listens to. Do not allow traffic to SSH port from the internet. 
 Doc for configuring GCP VPC firewalls using terraform:
- [google_compute_firewall](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall)
```tf
resource "google_compute_firewall" "allow-app" {
  name    = "allow-app-traffic"
  network = google_compute_network.vpc_network.name 
  
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_tags = ["webapp"]
}

```

- Launch GCP VM instance using Terraform: 
- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
- [GCP Operating system details](https://cloud.google.com/compute/docs/images/os-details)
```tf
resource "google_compute_instance" "webapp_instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  tags         = ["webapp"]
  
  boot_disk {
    initialize_params {
      image = var.image
      type = var.disk_type
      size = var.disk_size
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.webapp_subnet.name
  }
}
```

- Create `outputs.tf`, Output values make information about your infrastructure available on the command line, and can expose information for other Terraform configurations to use. Output values are similar to return values in programming languages.

```tf
output "vpc_id" {
	value = google_compute_network.vpc_network.id
}
```

1. Provisioning Infrastructure with Terraform

- Run `terraform init` cmd in the project folder to init the project into a terraform project
- Run `terraform plan` command: it creates an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure.
- Run `terraform apply` command: it executes the actions proposed in a Terraform plan.
