# 1. Fetch GCP client credentials
data "google_client_config" "default" {}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  deletion_protection = false
  initial_node_count = var.node_count

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 20
  }

  remove_default_node_pool = false
}


# 3. Get cluster details after creation
data "google_container_cluster" "gke_cluster" {
  name     = google_container_cluster.primary.name
  location = google_container_cluster.primary.location
  depends_on = [google_container_cluster.primary]
}

# 4. Kubernetes Provider using GKE credentials
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.gke_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
}

# 5. Helm Provider using the same credentials
provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.gke_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
  }
}

# 6. Harness Delegate Module Deployment
module "delegate" {
  source = "harness/harness-delegate/kubernetes"
  version = "0.1.8"

  account_id       = "ucHySz2jQKKWQweZdXyCog"
  delegate_token   = "NTRhYTY0Mjg3NThkNjBiNjMzNzhjOGQyNjEwOTQyZjY="
  delegate_name    = "terraform-delegate-hardik"
  deploy_mode      = "KUBERNETES"
  namespace        = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io"
  delegate_image   = "us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:25.04.85701"
  replicas         = 1
  upgrader_enabled = true
}
