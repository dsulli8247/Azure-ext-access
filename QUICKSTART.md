# Quick Start Guide

This guide will help you deploy the Azure hub-spoke network architecture in 10 minutes.

## Prerequisites

1. Azure subscription
2. Azure CLI installed
3. Contributor or Owner role on the subscription

## Quick Deployment

### Step 1: Clone or Download

If you haven't already, get the code:
```bash
git clone https://github.com/dsulli8247/Azure-ext-access.git
cd Azure-ext-access
```

### Step 2: Login to Azure

```bash
az login
az account set --subscription <your-subscription-id>
```

### Step 3: Review Parameters (Optional)

Edit `main.parameters.json` to customize:
- Region (default: eastus)
- VNet names and address spaces
- Resource group name

### Step 4: Deploy

#### Option A: Using the deployment script (Recommended)
```bash
./deploy.sh
```

The script will:
- Validate your Azure login
- Show what will be deployed
- Ask for confirmation
- Deploy the infrastructure

#### Option B: Using Azure CLI directly
```bash
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### Step 5: Wait for Deployment

The deployment takes approximately 15-20 minutes. Key resources being deployed:
- 4 Virtual Networks
- 2 Azure Firewalls
- 1 Application Gateway with WAF
- 6 VNet Peerings
- Route Tables

### Step 6: Verify Deployment

```bash
# Check resource group
az group show --name rg-hub-spoke-network

# List all resources
az resource list --resource-group rg-hub-spoke-network -o table

# Get deployment outputs
az deployment sub show --name <deployment-name> --query properties.outputs
```

## What Gets Created

### Networks
- ✅ Hub VNet (10.0.0.0/16) with Azure Firewall
- ✅ Spoke 1 VNet (10.1.0.0/16)
- ✅ Spoke 2 VNet (10.2.0.0/16)
- ✅ DMZ Spoke VNet (10.3.0.0/16) with Firewall and WAF

### Security
- ✅ Hub Azure Firewall (central traffic control)
- ✅ DMZ Azure Firewall (additional protection)
- ✅ Application Gateway v2 with WAF (OWASP 3.2)

### Connectivity
- ✅ All VNets peered in hub-spoke topology
- ✅ Route tables configured for east/west traffic via hub

## Next Steps

### 1. Configure Firewall Rules

The firewalls are deployed but need rules configured:

```bash
# Example: Add network rule to allow SSH
az network firewall network-rule create \
  --resource-group rg-hub-spoke-network \
  --firewall-name afw-vnet-hub \
  --collection-name 'AllowSSH' \
  --name 'allow-ssh' \
  --protocols 'TCP' \
  --source-addresses '*' \
  --destination-addresses '*' \
  --destination-ports '22' \
  --action 'Allow' \
  --priority 100
```

### 2. Configure Application Gateway Backend

Add your web applications to the Application Gateway:

```bash
# Add backend server
az network application-gateway address-pool update \
  --gateway-name agw-vnet-dmz-spoke \
  --resource-group rg-hub-spoke-network \
  --name defaultBackendPool \
  --servers <your-backend-ip>
```

### 3. Deploy Workloads

Deploy VMs or other resources to the spoke VNets:
- Spoke 1: Business applications
- Spoke 2: Database tier
- DMZ Spoke: Web tier

### 4. Enable Monitoring

```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group rg-hub-spoke-network \
  --workspace-name law-network-monitoring

# Enable firewall diagnostics
az monitor diagnostic-settings create \
  --resource /subscriptions/<sub-id>/resourceGroups/rg-hub-spoke-network/providers/Microsoft.Network/azureFirewalls/afw-vnet-hub \
  --name firewall-diagnostics \
  --workspace <workspace-id> \
  --logs '[{"category":"AzureFirewallApplicationRule","enabled":true},{"category":"AzureFirewallNetworkRule","enabled":true}]'
```

### 5. Harden Security

1. **Change WAF to Prevention Mode**:
```bash
az network application-gateway waf-config set \
  --gateway-name agw-vnet-dmz-spoke \
  --resource-group rg-hub-spoke-network \
  --enabled true \
  --firewall-mode Prevention
```

2. **Add Network Security Groups** to subnets for additional protection

3. **Configure DDoS Protection** on VNets

## Testing Connectivity

### Test 1: Verify VNet Peering
```bash
# Check peering status
az network vnet peering list \
  --resource-group rg-hub-spoke-network \
  --vnet-name vnet-hub \
  -o table
```

All peerings should show `PeeringState: Connected`

### Test 2: Verify Routing
```bash
# Check route tables
az network route-table route list \
  --resource-group rg-hub-spoke-network \
  --route-table-name rt-vnet-spoke1-workload \
  -o table
```

You should see routes pointing to the hub firewall IP.

### Test 3: Verify Firewall
```bash
# Get firewall status
az network firewall show \
  --resource-group rg-hub-spoke-network \
  --name afw-vnet-hub \
  --query "provisioningState"
```

Should return `"Succeeded"`

## Troubleshooting

### Deployment Fails

**Check quota limits**:
```bash
az vm list-usage --location eastus -o table
```

**View detailed error**:
```bash
az deployment sub show --name <deployment-name> --query properties.error
```

### Can't Connect Between Spokes

1. Check firewall rules are configured
2. Verify route tables are associated with subnets
3. Check VNet peering status

### High Costs

The infrastructure costs ~$2,500/month. To reduce costs:
1. Delete DMZ firewall if not needed
2. Scale down Application Gateway
3. Delete the entire deployment when not in use:
```bash
az group delete --name rg-hub-spoke-network --yes
```

## Clean Up

To remove all resources:

```bash
az group delete --name rg-hub-spoke-network --yes --no-wait
```

This will delete all resources in the resource group. The operation takes 10-15 minutes.

## Cost Estimate

Expected monthly costs:
- **Development**: ~$1,500/month (with optimizations)
- **Production**: ~$2,500/month (full deployment)

Monitor costs with:
```bash
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31
```

## Getting Help

- Review the [README.md](README.md) for detailed documentation
- Review the [ARCHITECTURE.md](ARCHITECTURE.md) for design details
- Check [Azure Firewall docs](https://docs.microsoft.com/en-us/azure/firewall/)
- Check [Application Gateway docs](https://docs.microsoft.com/en-us/azure/application-gateway/)

## Additional Resources

- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Hub-Spoke Network Topology](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
