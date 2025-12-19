# GCP Hub-Spoke Network Architecture with Terraform

This directory contains Terraform infrastructure as code for deploying a hub-spoke network topology on Google Cloud Platform (GCP) with Cloud Armor WAF and centralized routing.

## Architecture Overview

This deployment creates:

### Hub VPC
- **VPC**: `vpc-hub` (10.0.0.0/16)
- **Cloud NAT**: Central NAT gateway for egress traffic
- **Subnets**:
  - Firewall subnet: 10.0.1.0/24
  - Gateway subnet: 10.0.2.0/24
  - Bastion subnet: 10.0.3.0/24

### Spoke VPCs (Standard)
1. **vpc-spoke1** (10.1.0.0/16)
   - Workload subnet: 10.1.1.0/24
   - Routes traffic through hub

2. **vpc-spoke2** (10.2.0.0/16)
   - Workload subnet: 10.2.1.0/24
   - Routes traffic through hub

### DMZ Spoke VPC
- **VPC**: `vpc-dmz-spoke` (10.3.0.0/16)
- **Cloud Armor**: WAF for web application protection
- **HTTPS Load Balancer**: For front-end web application traffic
- **Subnets**:
  - Firewall subnet: 10.3.1.0/24
  - Load Balancer subnet: 10.3.2.0/24
  - Workload subnet: 10.3.3.0/24

### Network Topology
- All VPCs are peered in a hub-spoke topology
- Hub VPC provides centralized egress through Cloud NAT
- DMZ spoke has Cloud Armor WAF and HTTPS Load Balancer for front-end protection

## GCP vs Azure Architecture Mapping

| Azure Component | GCP Equivalent |
|----------------|----------------|
| Virtual Network (VNet) | Virtual Private Cloud (VPC) |
| Azure Firewall | Cloud NAT + Firewall Rules |
| Application Gateway with WAF | Cloud Load Balancer + Cloud Armor |
| VNet Peering | VPC Peering |
| User-Defined Routes | Custom Routes |
| Network Security Groups | Firewall Rules |
| Azure Bastion | Identity-Aware Proxy (IAP) |

## Prerequisites

- GCP project with billing enabled
- gcloud CLI installed ([Install gcloud](https://cloud.google.com/sdk/docs/install))
- Terraform installed ([Install Terraform](https://www.terraform.io/downloads.html))
- Appropriate GCP permissions (Project Editor or Owner role)

## Deployment

### 1. Login to GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-project-id>
```

### 2. Configure Terraform variables

Create `terraform.tfvars` from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your project ID:

```hcl
project_id = "your-gcp-project-id"
region     = "us-east1"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Validate the Terraform configuration

```bash
terraform validate
```

### 5. Deploy using Terraform

#### Option A: Use the deployment script

```bash
./deploy.sh
```

#### Option B: Deploy with Terraform commands

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply
```

### 6. Preview Changes (Terraform Plan)

To preview what resources will be created without actually deploying:

```bash
terraform plan
```

## File Structure

```
GCP/
├── main.tf                      # Main deployment file
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── terraform.tfvars.example     # Example variables file
├── deploy.sh                    # Deployment script
├── modules/
│   ├── hub-vpc/                # Hub VPC with Cloud NAT
│   │   └── main.tf
│   ├── spoke-vpc/              # Standard spoke VPC module
│   │   └── main.tf
│   ├── dmz-spoke-vpc/          # DMZ spoke with Cloud Armor and LB
│   │   └── main.tf
│   └── vpc-peering/            # VPC peering module
│       └── main.tf
└── README.md                    # This file
```

## Customization

You can customize the deployment by modifying the variables in `terraform.tfvars`:

- **project_id**: Your GCP project ID
- **region**: GCP region for deployment
- **hub_vpc_config**: Hub VPC CIDR and subnet configurations
- **spoke_vpc_configs**: Array of spoke VPC configurations
- **dmz_spoke_vpc_config**: DMZ spoke VPC configuration

## Security Considerations

1. **Firewall Rules**: Configure firewall rules according to your security requirements
2. **Cloud Armor**: The Cloud Armor WAF is deployed with basic rules - configure as needed
3. **IAP**: Use Identity-Aware Proxy for secure SSH access to instances
4. **Custom Routes**: Spoke VPCs can be configured to route through hub

## Cost Optimization

This deployment creates several resources that incur costs:
- VPC networks (free)
- Cloud NAT gateway (~$45/month)
- HTTPS Load Balancer (~$18/month + traffic)
- Cloud Armor (first 5 rules free, then ~$5/rule/month)
- VPC Peering (egress charges apply)

Consider using the following for dev/test environments:
- Single VPC instead of multiple VPCs
- Remove Cloud Armor for non-production
- Use fewer spoke VPCs

## Clean Up

To remove all deployed resources:

```bash
terraform destroy
```

Or delete individual resources:

```bash
gcloud compute networks delete vpc-hub --project=<project-id>
gcloud compute networks delete vpc-spoke1 --project=<project-id>
gcloud compute networks delete vpc-spoke2 --project=<project-id>
gcloud compute networks delete vpc-dmz-spoke --project=<project-id>
```

## Resources Created

The deployment creates the following GCP resources:

- 4 VPC Networks (1 hub + 3 spokes)
- 7 Subnets across VPCs
- 1 Cloud NAT Gateway
- 1 Cloud Router
- 1 HTTPS Load Balancer with Cloud Armor
- 1 Cloud Armor Security Policy
- Multiple Firewall Rules
- 6 VPC Peerings (bidirectional between hub and each spoke)
- External IP addresses

## Troubleshooting

### Deployment Failures

1. **Check Terraform state**:
```bash
terraform show
```

2. **View detailed logs**:
```bash
terraform apply -debug
```

### Common Issues

- **Insufficient permissions**: Ensure you have Project Editor or Owner role
- **API not enabled**: Enable required APIs (Compute Engine API, Cloud Armor API)
- **Quota limits**: Check GCP quotas for VPCs, IPs, and other resources
- **Address space conflicts**: Ensure VPC CIDR ranges don't overlap

### Enable Required APIs

```bash
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
```

## Differences from Azure Implementation

1. **Firewall**: GCP uses firewall rules at the VPC level instead of dedicated firewall appliances
2. **NAT**: Cloud NAT provides centralized egress instead of Azure Firewall
3. **WAF**: Cloud Armor is integrated with Load Balancer instead of Application Gateway
4. **Routing**: GCP uses VPC peering for inter-VPC routing instead of User-Defined Routes with next-hop appliances
5. **Access**: IAP provides secure access instead of Azure Bastion

### Important Routing Notes

**GCP Hub-Spoke Routing Model:**
- VPC peering automatically handles routing between peered VPCs
- Cloud NAT in the hub provides centralized egress for all peered networks
- Unlike Azure's User-Defined Routes, GCP custom routes with next-hop IPs require a VM/network appliance
- For advanced routing scenarios (e.g., next-gen firewalls), deploy a Network Virtual Appliance (NVA) in the hub

**Azure Hub-Spoke Routing Model:**
- Route tables with next-hop virtual appliance IP addresses
- Azure Firewall acts as the next-hop for all spoke traffic
- More explicit routing control through route tables

Both models achieve the same security posture and traffic flow, but use different mechanisms. GCP's approach is more distributed and automatic through VPC peering, while Azure's is more explicit through route tables.

## License

MIT License
