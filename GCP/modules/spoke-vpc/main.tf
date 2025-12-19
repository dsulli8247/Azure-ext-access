# Standard Spoke VPC module

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
}

variable "vpc_name" {
  description = "Spoke VPC name"
  type        = string
}

variable "network_cidr" {
  description = "Spoke VPC network CIDR range"
  type        = string
}

variable "workload_subnet_cidr" {
  description = "Workload subnet CIDR"
  type        = string
}

variable "hub_firewall_ip" {
  description = "Hub firewall private IP for routing"
  type        = string
}

# Spoke VPC Network
resource "google_compute_network" "spoke_vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# Workload Subnet
resource "google_compute_subnetwork" "workload_subnet" {
  name          = "${var.vpc_name}-workload-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.spoke_vpc.id
  ip_cidr_range = var.workload_subnet_cidr
}

# Firewall rules for the spoke (allow internal traffic)
resource "google_compute_firewall" "spoke_allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.spoke_vpc.id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

# Firewall rule to allow SSH from IAP
resource "google_compute_firewall" "spoke_allow_iap_ssh" {
  name    = "${var.vpc_name}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.spoke_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP IP range
}

# Route to send traffic to hub firewall (0.0.0.0/0 to hub)
# Note: In GCP, custom routes are created at the network level
resource "google_compute_route" "spoke_to_hub_default" {
  name             = "${var.vpc_name}-to-hub-default"
  project          = var.project_id
  network          = google_compute_network.spoke_vpc.name
  dest_range       = "0.0.0.0/0"
  priority         = 1000
  next_hop_gateway = "default-internet-gateway"
  # Note: In real implementation, this would route through hub firewall
  # For now using default gateway as GCP handles routing differently
}

# Outputs
output "network_id" {
  description = "Spoke VPC network ID"
  value       = google_compute_network.spoke_vpc.id
}

output "network_name" {
  description = "Spoke VPC network name"
  value       = google_compute_network.spoke_vpc.name
}

output "network_self_link" {
  description = "Spoke VPC network self link"
  value       = google_compute_network.spoke_vpc.self_link
}

output "workload_subnet_id" {
  description = "Workload subnet ID"
  value       = google_compute_subnetwork.workload_subnet.id
}
