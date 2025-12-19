# Hub VPC with Cloud Firewall module

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
}

variable "vpc_name" {
  description = "Hub VPC name"
  type        = string
}

variable "network_cidr" {
  description = "Hub VPC network CIDR range"
  type        = string
}

variable "firewall_subnet_cidr" {
  description = "Firewall subnet CIDR"
  type        = string
}

variable "gateway_subnet_cidr" {
  description = "Gateway subnet CIDR"
  type        = string
}

variable "bastion_subnet_cidr" {
  description = "Bastion subnet CIDR"
  type        = string
}

# Hub VPC Network
resource "google_compute_network" "hub_vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# Firewall Subnet
resource "google_compute_subnetwork" "firewall_subnet" {
  name          = "${var.vpc_name}-firewall-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.hub_vpc.id
  ip_cidr_range = var.firewall_subnet_cidr
}

# Gateway Subnet
resource "google_compute_subnetwork" "gateway_subnet" {
  name          = "${var.vpc_name}-gateway-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.hub_vpc.id
  ip_cidr_range = var.gateway_subnet_cidr
}

# Bastion Subnet
resource "google_compute_subnetwork" "bastion_subnet" {
  name          = "${var.vpc_name}-bastion-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.hub_vpc.id
  ip_cidr_range = var.bastion_subnet_cidr
}

# Reserve Internal IP for Firewall
resource "google_compute_address" "firewall_internal_ip" {
  name         = "${var.vpc_name}-firewall-ip"
  project      = var.project_id
  region       = var.region
  subnetwork   = google_compute_subnetwork.firewall_subnet.id
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

# External IP for NAT Gateway (simulating firewall egress)
resource "google_compute_address" "nat_gateway_ip" {
  name    = "${var.vpc_name}-nat-gateway-ip"
  project = var.project_id
  region  = var.region
}

# Cloud Router for NAT
resource "google_compute_router" "hub_router" {
  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.hub_vpc.id
}

# Cloud NAT (acts as central egress point similar to Azure Firewall)
resource "google_compute_router_nat" "hub_nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.hub_router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_gateway_ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rules for the hub (allow internal traffic)
resource "google_compute_firewall" "hub_allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.hub_vpc.id

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
resource "google_compute_firewall" "hub_allow_iap_ssh" {
  name    = "${var.vpc_name}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.hub_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP IP range
}

# Outputs
output "network_id" {
  description = "Hub VPC network ID"
  value       = google_compute_network.hub_vpc.id
}

output "network_name" {
  description = "Hub VPC network name"
  value       = google_compute_network.hub_vpc.name
}

output "network_self_link" {
  description = "Hub VPC network self link"
  value       = google_compute_network.hub_vpc.self_link
}

output "firewall_ip" {
  description = "Firewall internal IP address"
  value       = google_compute_address.firewall_internal_ip.address
}

output "nat_gateway_ip" {
  description = "NAT Gateway external IP address"
  value       = google_compute_address.nat_gateway_ip.address
}
