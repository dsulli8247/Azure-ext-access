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
  description = "Hub firewall private IP for routing (not used in GCP - routing via VPC peering)"
  type        = string
}

# Note: In GCP, the hub-spoke routing model works differently than Azure:
# - VPC peering automatically handles routing between peered VPCs
# - Cloud NAT at the hub level handles egress traffic for all peered VPCs
# - Custom routes with next-hop IPs require a VM/appliance, not just an IP address
# The hub_firewall_ip is kept for API compatibility but not actively used

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
# Note: In GCP, routing works differently than Azure's User-Defined Routes:
# - VPC peering automatically handles routing between peered networks
# - Custom routes with next-hop IPs require a VM/network appliance instance
# - Cloud NAT in the hub VPC handles centralized egress for all peered VPCs
# - This route sends to default gateway; for custom routing, deploy a network virtual appliance
resource "google_compute_route" "spoke_default_internet" {
  name             = "${var.vpc_name}-default-internet"
  project          = var.project_id
  network          = google_compute_network.spoke_vpc.name
  dest_range       = "0.0.0.0/0"
  priority         = 1000
  next_hop_gateway = "default-internet-gateway"

  # For hub-based routing in GCP, you would need to:
  # 1. Deploy a network virtual appliance (NVA) in the hub with the firewall IP
  # 2. Set next_hop_instance or next_hop_ip pointing to that NVA
  # 3. Configure the NVA to forward traffic appropriately
  # Example: next_hop_instance = "projects/${var.project_id}/zones/us-east1-b/instances/hub-firewall-vm"
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
