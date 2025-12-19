# Main Terraform file for GCP Hub-Spoke Architecture
# This deploys a hub VPC with Cloud Firewall and 3 spoke VPCs
# DMZ spoke includes Cloud Armor and Load Balancer

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Deploy Hub VPC with Cloud Firewall
module "hub_vpc" {
  source = "./modules/hub-vpc"

  project_id           = var.project_id
  region               = var.region
  vpc_name             = var.hub_vpc_config.name
  network_cidr         = var.hub_vpc_config.network_cidr
  firewall_subnet_cidr = var.hub_vpc_config.firewall_subnet_cidr
  gateway_subnet_cidr  = var.hub_vpc_config.gateway_subnet_cidr
  bastion_subnet_cidr  = var.hub_vpc_config.bastion_subnet_cidr
}

# Deploy Standard Spoke VPCs
module "spoke_vpcs" {
  source   = "./modules/spoke-vpc"
  for_each = { for idx, spoke in var.spoke_vpc_configs : spoke.name => spoke }

  project_id           = var.project_id
  region               = var.region
  vpc_name             = each.value.name
  network_cidr         = each.value.network_cidr
  workload_subnet_cidr = each.value.workload_subnet_cidr
  hub_firewall_ip      = module.hub_vpc.firewall_ip
}

# Deploy DMZ Spoke VPC with Cloud Armor and Load Balancer
module "dmz_spoke_vpc" {
  source = "./modules/dmz-spoke-vpc"

  project_id           = var.project_id
  region               = var.region
  vpc_name             = var.dmz_spoke_vpc_config.name
  network_cidr         = var.dmz_spoke_vpc_config.network_cidr
  firewall_subnet_cidr = var.dmz_spoke_vpc_config.firewall_subnet_cidr
  lb_subnet_cidr       = var.dmz_spoke_vpc_config.lb_subnet_cidr
  workload_subnet_cidr = var.dmz_spoke_vpc_config.workload_subnet_cidr
  hub_firewall_ip      = module.hub_vpc.firewall_ip
}

# Create VPC Peerings - Hub to Spokes
module "hub_to_spoke_peerings" {
  source   = "./modules/vpc-peering"
  for_each = { for idx, spoke in var.spoke_vpc_configs : spoke.name => spoke }

  project_id          = var.project_id
  local_network_name  = var.hub_vpc_config.name
  local_network_id    = module.hub_vpc.network_id
  remote_network_name = each.value.name
  remote_network_id   = module.spoke_vpcs[each.value.name].network_id
  peering_name        = "hub-to-${each.value.name}"
}

# Create VPC Peerings - Spokes to Hub
module "spoke_to_hub_peerings" {
  source   = "./modules/vpc-peering"
  for_each = { for idx, spoke in var.spoke_vpc_configs : spoke.name => spoke }

  project_id          = var.project_id
  local_network_name  = each.value.name
  local_network_id    = module.spoke_vpcs[each.value.name].network_id
  remote_network_name = var.hub_vpc_config.name
  remote_network_id   = module.hub_vpc.network_id
  peering_name        = "${each.value.name}-to-hub"
}

# Create VPC Peering - Hub to DMZ Spoke
module "hub_to_dmz_peering" {
  source = "./modules/vpc-peering"

  project_id          = var.project_id
  local_network_name  = var.hub_vpc_config.name
  local_network_id    = module.hub_vpc.network_id
  remote_network_name = var.dmz_spoke_vpc_config.name
  remote_network_id   = module.dmz_spoke_vpc.network_id
  peering_name        = "hub-to-dmz"
}

# Create VPC Peering - DMZ Spoke to Hub
module "dmz_to_hub_peering" {
  source = "./modules/vpc-peering"

  project_id          = var.project_id
  local_network_name  = var.dmz_spoke_vpc_config.name
  local_network_id    = module.dmz_spoke_vpc.network_id
  remote_network_name = var.hub_vpc_config.name
  remote_network_id   = module.hub_vpc.network_id
  peering_name        = "dmz-to-hub"
}
