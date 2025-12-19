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
  description = "Hub firewall private IP (reserved for future NVA implementation)"
  type        = string
}

# GCP Hub-Spoke Routing Notes:
# In GCP's routing model:
# 1. VPC peering automatically handles routing between peered VPCs
# 2. Cloud NAT in the hub VPC handles centralized egress for all peered networks
# 3. No explicit routes are needed - VPC peering propagates routes automatically
# 4. For advanced routing through an NVA, deploy a VM in the hub and use next_hop_instance
#
# The hub_firewall_ip parameter is reserved for future Network Virtual Appliance (NVA)
# implementations but is not used in the current VPC peering-based routing model.

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

# Note: No custom routes are needed for the hub-spoke model in GCP
# VPC peering automatically handles routing between peered VPCs, and Cloud NAT
# in the hub VPC provides centralized egress. GCP uses a default route to the
# internet gateway, which Cloud NAT intercepts for NAT translation.
# For advanced scenarios requiring traffic inspection, deploy a Network Virtual
# Appliance (NVA) in the hub and create custom routes with next_hop_instance.

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
