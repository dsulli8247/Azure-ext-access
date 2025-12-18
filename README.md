# Azure Hub-Spoke Network Architecture with Bicep

This repository contains Azure Bicep infrastructure as code for deploying a hub-spoke network topology with Azure Firewalls and a Web Application Firewall (WAF).

## Architecture Overview

This deployment creates:

### Hub VNet
- **VNet**: `vnet-hub` (10.0.0.0/16)
- **Azure Firewall**: Central firewall for all east/west traffic
- **Subnets**:
  - AzureFirewallSubnet: 10.0.1.0/24
  - GatewaySubnet: 10.0.2.0/24
  - AzureBastionSubnet: 10.0.3.0/24

### Spoke VNets (Standard)
1. **vnet-spoke1** (10.1.0.0/16)
   - Workload subnet: 10.1.1.0/24
   - Routes traffic through hub firewall

2. **vnet-spoke2** (10.2.0.0/16)
   - Workload subnet: 10.2.1.0/24
   - Routes traffic through hub firewall

### DMZ Spoke VNet
- **VNet**: `vnet-dmz-spoke` (10.3.0.0/16)
- **Azure Firewall**: DMZ firewall for additional security
- **Application Gateway v2 with WAF**: For front-end web application protection
- **Subnets**:
  - AzureFirewallSubnet: 10.3.1.0/24
  - Application Gateway subnet: 10.3.2.0/24
  - Workload subnet: 10.3.3.0/24

### Network Topology
- All VNets are peered in a hub-spoke topology
- All east/west traffic is routed through the hub firewall
- DMZ spoke has additional firewall and WAF for front-end protection

## Prerequisites

- Azure subscription
- Azure CLI installed ([Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Bicep CLI (installed with Azure CLI 2.20.0+)
- Appropriate Azure permissions to create resources

## Deployment

### 1. Login to Azure

```bash
az login
az account set --subscription <your-subscription-id>
```

### 2. Validate the Bicep template

```bash
az bicep build --file main.bicep
```

### 3. Deploy using Azure CLI

#### Option A: Deploy with parameter file

```bash
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters main.parameters.json
```

#### Option B: Deploy with inline parameters

```bash
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters location=eastus resourceGroupName=rg-hub-spoke-network
```

### 4. What-If Deployment (Preview Changes)

To preview what resources will be created without actually deploying:

```bash
az deployment sub what-if \
  --location eastus \
  --template-file main.bicep \
  --parameters main.parameters.json
```

## File Structure

```
.
├── main.bicep                      # Main deployment file (subscription scope)
├── main.parameters.json            # Parameters file for deployment
├── modules/
│   ├── hub-vnet.bicep             # Hub VNet with Azure Firewall
│   ├── spoke-vnet.bicep           # Standard spoke VNet module
│   ├── dmz-spoke-vnet.bicep       # DMZ spoke with Firewall and WAF
│   └── vnet-peering.bicep         # VNet peering module
└── README.md                       # This file
```

## Customization

You can customize the deployment by modifying the parameters in `main.parameters.json`:

- **location**: Azure region for deployment
- **resourceGroupName**: Name of the resource group
- **hubVNetConfig**: Hub VNet address spaces
- **spokeVNetConfigs**: Array of spoke VNet configurations
- **dmzSpokeVNetConfig**: DMZ spoke VNet configuration

## Security Considerations

1. **Azure Firewalls**: Configure firewall rules according to your security requirements
2. **WAF Policy**: The Application Gateway WAF is deployed in Detection mode - configure rules as needed
3. **Network Security Groups**: Consider adding NSGs for additional subnet-level security
4. **Route Tables**: All spoke workload subnets route through the hub firewall (0.0.0.0/0)

## Cost Optimization

This deployment creates several expensive resources:
- 2x Azure Firewalls (Hub + DMZ)
- 1x Application Gateway v2 with WAF
- Public IP addresses

Consider using the following for dev/test environments:
- Azure Firewall Basic tier
- Smaller Application Gateway SKUs
- Fewer spoke VNets

## Clean Up

To remove all deployed resources:

```bash
az group delete --name rg-hub-spoke-network --yes --no-wait
```

## Resources Created

The deployment creates the following Azure resources:

- 1 Resource Group
- 4 Virtual Networks (1 hub + 3 spokes)
- 2 Azure Firewalls (hub + DMZ)
- 2 Azure Firewall Policies
- 1 Application Gateway v2 with WAF
- 3 Public IP addresses (2 firewalls + 1 app gateway)
- 3 Route Tables (for spoke workload subnets)
- 6 VNet Peerings (bidirectional between hub and each spoke)
- Multiple subnets across VNets

## Troubleshooting

### Deployment Failures

1. **Check deployment status**:
```bash
az deployment sub show --name <deployment-name>
```

2. **View deployment logs**:
```bash
az deployment sub operation list --name <deployment-name>
```

### Common Issues

- **Insufficient permissions**: Ensure you have Contributor or Owner role
- **Quota limits**: Check Azure subscription quotas for Public IPs and other resources
- **Address space conflicts**: Ensure VNet address spaces don't overlap

## License

MIT License