provider "google" {
  project = var.project_id
  region  = var.region
  zone    = "${var.region}-b"
}

provider "random" {}