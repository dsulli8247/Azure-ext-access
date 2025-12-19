# VPC Peering module

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "local_network_name" {
  description = "Local VPC network name"
  type        = string
}

variable "local_network_id" {
  description = "Local VPC network ID"
  type        = string
}

variable "remote_network_name" {
  description = "Remote VPC network name"
  type        = string
}

variable "remote_network_id" {
  description = "Remote VPC network ID"
  type        = string
}

variable "peering_name" {
  description = "Name for the VPC peering"
  type        = string
}

# VPC Network Peering
resource "google_compute_network_peering" "peering" {
  name         = var.peering_name
  network      = var.local_network_id
  peer_network = var.remote_network_id

  export_custom_routes = true
  import_custom_routes = true
}

# Outputs
output "peering_name" {
  description = "VPC peering name"
  value       = google_compute_network_peering.peering.name
}

output "peering_state" {
  description = "VPC peering state"
  value       = google_compute_network_peering.peering.state
}
