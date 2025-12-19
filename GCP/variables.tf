# Variables for GCP Hub-Spoke Architecture

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-east1"
}

variable "hub_vpc_config" {
  description = "Hub VPC configuration"
  type = object({
    name                 = string
    network_cidr         = string
    firewall_subnet_cidr = string
    gateway_subnet_cidr  = string
    bastion_subnet_cidr  = string
  })
  default = {
    name                 = "vpc-hub"
    network_cidr         = "10.0.0.0/16"
    firewall_subnet_cidr = "10.0.1.0/24"
    gateway_subnet_cidr  = "10.0.2.0/24"
    bastion_subnet_cidr  = "10.0.3.0/24"
  }
}

variable "spoke_vpc_configs" {
  description = "Spoke VPC configurations"
  type = list(object({
    name                 = string
    network_cidr         = string
    workload_subnet_cidr = string
  }))
  default = [
    {
      name                 = "vpc-spoke1"
      network_cidr         = "10.1.0.0/16"
      workload_subnet_cidr = "10.1.1.0/24"
    },
    {
      name                 = "vpc-spoke2"
      network_cidr         = "10.2.0.0/16"
      workload_subnet_cidr = "10.2.1.0/24"
    }
  ]
}

variable "dmz_spoke_vpc_config" {
  description = "DMZ Spoke VPC configuration"
  type = object({
    name                  = string
    network_cidr          = string
    firewall_subnet_cidr  = string
    lb_subnet_cidr        = string
    workload_subnet_cidr  = string
    gke_subnet_cidr       = string
    gke_pods_ip_range     = optional(string, "10.4.0.0/16")
    gke_services_ip_range = optional(string, "10.5.0.0/16")
  })
  default = {
    name                  = "vpc-dmz-spoke"
    network_cidr          = "10.3.0.0/16"
    firewall_subnet_cidr  = "10.3.1.0/24"
    lb_subnet_cidr        = "10.3.2.0/24"
    workload_subnet_cidr  = "10.3.3.0/24"
    gke_subnet_cidr       = "10.3.4.0/24"
    gke_pods_ip_range     = "10.4.0.0/16"
    gke_services_ip_range = "10.5.0.0/16"
  }
}

variable "gke_config" {
  description = "GKE cluster configuration"
  type = object({
    enabled            = bool
    cluster_name       = string
    kubernetes_version = string
    node_machine_type  = string
    node_count         = number
    min_node_count     = number
    max_node_count     = number
  })
  default = {
    enabled            = true
    cluster_name       = "gke-dmz-cluster"
    kubernetes_version = "1.32"
    node_machine_type  = "e2-medium"
    node_count         = 2
    min_node_count     = 1
    max_node_count     = 3
  }
}
