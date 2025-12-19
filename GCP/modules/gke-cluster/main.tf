# Google Kubernetes Engine (GKE) Cluster module

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for GKE nodes"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name for GKE nodes"
  type        = string
}

variable "node_config" {
  description = "Node pool configuration"
  type = object({
    machine_type   = string
    node_count     = number
    min_node_count = number
    max_node_count = number
  })
  default = {
    machine_type   = "e2-medium"
    node_count     = 2
    min_node_count = 1
    max_node_count = 3
  }
}

# GKE Cluster
resource "google_container_cluster" "gke_cluster" {
  name               = var.cluster_name
  project            = var.project_id
  location           = var.region
  min_master_version = var.kubernetes_version

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_id
  subnetwork = var.subnet_id

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network policy
  network_policy {
    enabled = true
  }

  # Enable VPC-native traffic routing
  networking_mode = "VPC_NATIVE"

  # Release channel for automatic updates
  release_channel {
    channel = "REGULAR"
  }

  # Enable Autopilot features (optional)
  # Note: Autopilot and node pools are mutually exclusive
  # autopilot {
  #   enabled = true
  # }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Private cluster configuration (optional for enhanced security)
  # private_cluster_config {
  #   enable_private_nodes    = true
  #   enable_private_endpoint = false
  #   master_ipv4_cidr_block  = "172.16.0.0/28"
  # }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.gke_cluster.name
  node_count = var.node_config.node_count

  # Autoscaling configuration
  autoscaling {
    min_node_count = var.node_config.min_node_count
    max_node_count = var.node_config.max_node_count
  }

  # Node configuration
  node_config {
    machine_type = var.node_config.machine_type
    
    # Google recommends custom service accounts with minimal permissions
    service_account = google_service_account.gke_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Labels
    labels = {
      environment = "dmz"
      managed-by  = "terraform"
    }

    # Taints (optional)
    # taint {
    #   key    = "dedicated"
    #   value  = "gke"
    #   effect = "NO_SCHEDULE"
    # }

    # Security
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Disk configuration
    disk_size_gb = 100
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"
  }

  # Node pool management
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service Account for GKE nodes
resource "google_service_account" "gke_sa" {
  account_id   = "${var.cluster_name}-sa"
  project      = var.project_id
  display_name = "Service Account for ${var.cluster_name}"
}

# IAM binding for GKE service account
resource "google_project_iam_member" "gke_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# Outputs
output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.gke_cluster.id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke_cluster.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.gke_cluster.endpoint
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "service_account_email" {
  description = "Service account email for GKE nodes"
  value       = google_service_account.gke_sa.email
}
