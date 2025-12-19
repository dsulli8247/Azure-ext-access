# Outputs for GCP Hub-Spoke Architecture

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "hub_network_id" {
  description = "Hub VPC network ID"
  value       = module.hub_vpc.network_id
}

output "hub_network_name" {
  description = "Hub VPC network name"
  value       = module.hub_vpc.network_name
}

output "hub_firewall_ip" {
  description = "Hub firewall private IP"
  value       = module.hub_vpc.firewall_ip
}

output "spoke_network_ids" {
  description = "Spoke VPC network IDs"
  value       = { for name, spoke in module.spoke_vpcs : name => spoke.network_id }
}

output "spoke_network_names" {
  description = "Spoke VPC network names"
  value       = { for name, spoke in module.spoke_vpcs : name => spoke.network_name }
}

output "dmz_network_id" {
  description = "DMZ VPC network ID"
  value       = module.dmz_spoke_vpc.network_id
}

output "dmz_network_name" {
  description = "DMZ VPC network name"
  value       = module.dmz_spoke_vpc.network_name
}

output "dmz_load_balancer_ip" {
  description = "DMZ load balancer IP"
  value       = module.dmz_spoke_vpc.load_balancer_ip
}
