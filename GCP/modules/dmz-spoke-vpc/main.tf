# DMZ Spoke VPC with Cloud Armor and Load Balancer module

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
}

variable "vpc_name" {
  description = "DMZ Spoke VPC name"
  type        = string
}

variable "network_cidr" {
  description = "DMZ Spoke VPC network CIDR range"
  type        = string
}

variable "firewall_subnet_cidr" {
  description = "Firewall subnet CIDR"
  type        = string
}

variable "lb_subnet_cidr" {
  description = "Load Balancer subnet CIDR"
  type        = string
}

variable "workload_subnet_cidr" {
  description = "Workload subnet CIDR"
  type        = string
}

variable "gke_subnet_cidr" {
  description = "GKE subnet CIDR"
  type        = string
  default     = ""
}

variable "gke_pods_ip_range" {
  description = "Secondary IP range for GKE pods"
  type        = string
  default     = "10.4.0.0/16"
}

variable "gke_services_ip_range" {
  description = "Secondary IP range for GKE services"
  type        = string
  default     = "10.5.0.0/16"
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

# DMZ Spoke VPC Network
resource "google_compute_network" "dmz_vpc" {
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
  network       = google_compute_network.dmz_vpc.id
  ip_cidr_range = var.firewall_subnet_cidr
}

# Load Balancer Subnet
resource "google_compute_subnetwork" "lb_subnet" {
  name          = "${var.vpc_name}-lb-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.dmz_vpc.id
  ip_cidr_range = var.lb_subnet_cidr
}

# Workload Subnet
resource "google_compute_subnetwork" "workload_subnet" {
  name          = "${var.vpc_name}-workload-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.dmz_vpc.id
  ip_cidr_range = var.workload_subnet_cidr
}

# GKE Subnet
resource "google_compute_subnetwork" "gke_subnet" {
  count         = var.gke_subnet_cidr != "" ? 1 : 0
  name          = "${var.vpc_name}-gke-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.dmz_vpc.id
  ip_cidr_range = var.gke_subnet_cidr

  # Secondary IP ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_ip_range
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_ip_range
  }
}

# External IP for Load Balancer
resource "google_compute_global_address" "lb_external_ip" {
  name    = "${var.vpc_name}-lb-ip"
  project = var.project_id
}

# Cloud Armor Security Policy (WAF equivalent)
resource "google_compute_security_policy" "cloud_armor_policy" {
  name    = "${var.vpc_name}-cloud-armor-policy"
  project = var.project_id

  # Default rule
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  # OWASP ModSecurity Core Rule Set
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}

# Backend Service for Load Balancer
resource "google_compute_backend_service" "lb_backend" {
  name                  = "${var.vpc_name}-lb-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Attach Cloud Armor security policy
  security_policy = google_compute_security_policy.cloud_armor_policy.id

  backend {
    group           = google_compute_instance_group.lb_instance_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.http_health_check.id]
}

# Instance Group (empty for now, as placeholder)
resource "google_compute_instance_group" "lb_instance_group" {
  name    = "${var.vpc_name}-instance-group"
  project = var.project_id
  zone    = "${var.region}-b"
  network = google_compute_network.dmz_vpc.id

  named_port {
    name = "http"
    port = 80
  }
}

# Health Check
resource "google_compute_health_check" "http_health_check" {
  name    = "${var.vpc_name}-http-health-check"
  project = var.project_id

  http_health_check {
    port = 80
  }
}

# URL Map
resource "google_compute_url_map" "lb_url_map" {
  name            = "${var.vpc_name}-lb-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.lb_backend.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "lb_http_proxy" {
  name    = "${var.vpc_name}-lb-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.lb_url_map.id
}

# Forwarding Rule (Load Balancer front-end)
resource "google_compute_global_forwarding_rule" "lb_forwarding_rule" {
  name                  = "${var.vpc_name}-lb-forwarding-rule"
  project               = var.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.lb_http_proxy.id
  ip_address            = google_compute_global_address.lb_external_ip.id
}

# Firewall rules for the DMZ spoke
resource "google_compute_firewall" "dmz_allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.dmz_vpc.id

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

# Firewall rule to allow HTTP from internet
resource "google_compute_firewall" "dmz_allow_http" {
  name    = "${var.vpc_name}-allow-http"
  project = var.project_id
  network = google_compute_network.dmz_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Firewall rule to allow SSH from IAP
resource "google_compute_firewall" "dmz_allow_iap_ssh" {
  name    = "${var.vpc_name}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.dmz_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP IP range
}

# Outputs
output "network_id" {
  description = "DMZ VPC network ID"
  value       = google_compute_network.dmz_vpc.id
}

output "network_name" {
  description = "DMZ VPC network name"
  value       = google_compute_network.dmz_vpc.name
}

output "network_self_link" {
  description = "DMZ VPC network self link"
  value       = google_compute_network.dmz_vpc.self_link
}

output "load_balancer_ip" {
  description = "Load Balancer external IP address"
  value       = google_compute_global_address.lb_external_ip.address
}

output "cloud_armor_policy_id" {
  description = "Cloud Armor security policy ID"
  value       = google_compute_security_policy.cloud_armor_policy.id
}

output "workload_subnet_id" {
  description = "Workload subnet ID"
  value       = google_compute_subnetwork.workload_subnet.id
}

output "gke_subnet_id" {
  description = "GKE subnet ID"
  value       = length(google_compute_subnetwork.gke_subnet) > 0 ? google_compute_subnetwork.gke_subnet[0].id : ""
}

output "gke_subnet_name" {
  description = "GKE subnet name"
  value       = length(google_compute_subnetwork.gke_subnet) > 0 ? google_compute_subnetwork.gke_subnet[0].name : ""
}
